-- DROP SCHEMA IF EXISTS core_utils CASCADE;
CREATE SCHEMA IF NOT EXISTS core_utils;

-- * ==================================
-- * CONST FUNCTIONS - common constants used in other sql functions
-- * ==================================

CREATE OR REPLACE FUNCTION core_utils.const_table_active_data()
  RETURNS text IMMUTABLE LANGUAGE SQL AS
$$SELECT 'features.active_data'$$;

CREATE OR REPLACE FUNCTION core_utils.const_table_history_data()
  RETURNS text IMMUTABLE LANGUAGE SQL AS
$$SELECT 'features.history_data'$$;



/**
build where clause strings for woreda and for gefence for user
 */
create or replace function
    core_utils._build_dashboard_filter_woreda_geofence_where_clause_predicates(
        i_webuser_id integer
    )
returns text AS
$BODY$
declare
    l_is_staff boolean;
    l_geofence geometry;
    l_woreda_predicate text := '';
    l_geofence_predicate text := '';
begin

    -- check if user has is_staff

    EXECUTE format($k$select
            is_staff OR is_readonly,
            geofence
        FROM
            webusers_webuser
        where
            id = %L
    $k$, i_webuser_id) INTO l_is_staff, l_geofence;

     -- build woreda where clause predicate

    IF l_is_staff = FALSE THEN
        l_woreda_predicate := format(' AND woreda IN (SELECT unnest(values) FROM webusers_grant WHERE webuser_id = %L)',
                                     i_webuser_id);
    END IF;

    -- build geofence where clause predicate

    IF l_geofence IS NOT NULL THEN
        l_geofence_predicate := format(' AND st_within(point_geometry, %L)', l_geofence);
    END IF;

    return l_woreda_predicate || ' '|| l_geofence_predicate;
END;
$BODY$
LANGUAGE plpgsql;


-- * ==================================
-- * FEATURE FUNCTIONS
-- * ==================================

-- *
-- * core_utils.get_features, used od features / table reports
-- *
-- * has limit / offset pagination - TODO update to use row_number()

CREATE OR REPLACE FUNCTION core_utils.get_features(
    i_webuser_id integer, i_limit integer, i_offset integer, i_order_text text, i_search_predicates text, i_changest_id int DEFAULT NULL
)
  RETURNS SETOF text
LANGUAGE plpgsql
AS $fun$
DECLARE
    v_query            TEXT;
    l_woreda_predicate TEXT;
    l_geofence geometry;
    l_geofence_predicate TEXT;
    l_is_staff         BOOLEAN;
    l_changeset_predicate TEXT;
    l_table_name TEXT;
BEGIN

    -- check if user has is_staff
    v_query := format('select is_staff OR is_readonly, geofence FROM webusers_webuser where id = %L', i_webuser_id);

    EXECUTE v_query INTO l_is_staff, l_geofence;

    IF l_is_staff = FALSE
    THEN
        l_woreda_predicate := format('AND woreda IN (SELECT unnest(values) FROM webusers_grant WHERE webuser_id = %L)',
                                     i_webuser_id);
    ELSE
        l_woreda_predicate := NULL;
    END IF;

    -- geofence predicate
    IF l_geofence IS NOT NULL THEN
        l_geofence_predicate := format($$ AND st_within(attrs.point_geometry, %L)$$, l_geofence);
    ELSE
        l_geofence_predicate := NULL;
    END IF;

    -- changeset predicate
    IF i_changest_id IS NULL
    THEN
        l_changeset_predicate := '1=1';
        l_table_name := core_utils.const_table_active_data();
    ELSE
        l_changeset_predicate := format('changeset_id = %L', i_changest_id);
        l_table_name := core_utils.const_table_history_data();
    END IF;

    v_query := format($q$
    WITH user_data AS (
    SELECT
             ts as _last_update,
             email AS _webuser,
             *
         FROM %s attrs
         WHERE %s
         %s %s
    )

    select (jsonb_build_object('data', (
         SELECT coalesce(jsonb_agg(row), '[]') AS data
            FROM (
                SELECT * from user_data
                %s
                %s
                LIMIT %s OFFSET %s
            ) row)
        ) || jsonb_build_object(
                'recordsTotal',
                (Select count(*) from user_data)
        ) || jsonb_build_object(
                'recordsFiltered',
                (Select count(*) from user_data %s)
        )
    )::text
    $q$, l_table_name, l_changeset_predicate, l_woreda_predicate, l_geofence_predicate, i_search_predicates, i_order_text, i_limit, i_offset, i_search_predicates);
    RETURN QUERY EXECUTE v_query;
END;

$fun$;


CREATE or replace FUNCTION core_utils.insert_feature(i_webuser_id integer, i_feature_point_geometry geometry, i_feature_attributes text, i_feature_uuid uuid default NULL, i_changeset_id integer default NULL)
  RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    l_feature_uuid   uuid;
    l_feature_changeset integer;
    l_query text;
    l_query_template text;
    l_attribute_list text;
    l_email text;
    l_ts_created timestamp with time zone;
BEGIN

    if i_feature_uuid is null THEN
        -- create a new feature uuid
        l_feature_uuid := uuid_generate_v4();
    ELSE
        l_feature_uuid := i_feature_uuid;
    END IF;

    if i_changeset_id is null THEN
        -- create new changeset
        INSERT INTO
            features.changeset (webuser_id)
        VALUES (i_webuser_id) RETURNING id INTO l_feature_changeset;
    ELSE
        l_feature_changeset := i_changeset_id;
    END IF;

    -- get data related to the changeset
    select wu.email, chg.ts_created FROM features.changeset chg JOIN webusers_webuser wu ON chg.webuser_id = wu.id
    WHERE chg.id = l_feature_changeset
    INTO l_email, l_ts_created;

    -- which attributes are available
    l_query := $attributes$
    select
        string_agg(quote_ident(key), ', ' ORDER BY row_number) as attribute_list
    from (
        SELECT row_number() OVER (ORDER BY
            ag.position, aa.position), aa.key
        FROM
            attributes_attribute aa JOIN attributes_attributegroup ag on aa.attribute_group_id = ag.id
        WHERE
            aa.is_active = True
    ) d;
    $attributes$;

    EXECUTE l_query INTO l_attribute_list;

    l_query_template := $OUTER_QUERY$
        insert into %s (
            point_geometry,
            email,
            ts,
            feature_uuid,
            changeset_id,
            static_water_level_group_id, amount_of_deposited_group_id, yield_group_id,
            %s
        )

        select
            %L as point_geometry,
            %L as email,
            %L as ts,
            %L as feature_uuid,
            %L as changeset_id,
            CASE
                WHEN static_water_level >= 100
                  THEN 5
                WHEN static_water_level >= 50 AND static_water_level < 100
                  THEN 4
                WHEN static_water_level >= 20 AND static_water_level < 50
                  THEN 3
                WHEN static_water_level > 10 AND static_water_level < 20
                  THEN 2
                ELSE 1
            END AS static_water_level_group_id,
            CASE
              WHEN amount_of_deposited >= 5000
                  THEN 5
              WHEN amount_of_deposited >= 3000 AND amount_of_deposited < 5000
                  THEN 4
              WHEN amount_of_deposited >= 500 AND amount_of_deposited < 3000
                  THEN 3
              WHEN amount_of_deposited > 1 AND amount_of_deposited < 500
                  THEN 2
              ELSE 1
            END AS amount_of_deposited_group_id,
            CASE
                WHEN yield >= 6
                  THEN 5
                WHEN yield >= 3 AND yield < 6
                  THEN 4
                WHEN yield >= 1 AND yield < 3
                  THEN 3
                WHEN yield > 0 AND yield < 1
                  THEN 2
                ELSE 1
            END AS yield_group_id,
            %s -- other columns
            FROM (SELECT %s) computed_data

        $OUTER_QUERY$;

    -- generate query that will insert data to history_data
    l_query := format(l_query_template, core_utils.const_table_active_data(), l_attribute_list, i_feature_point_geometry, l_email, l_ts_created, l_feature_uuid, l_feature_changeset, l_attribute_list, core_utils.json_to_data(i_feature_attributes));
    EXECUTE l_query;

    -- generate query that will insert data to active_data
    l_query := format(l_query_template, core_utils.const_table_history_data(), l_attribute_list, i_feature_point_geometry, l_email, l_ts_created, l_feature_uuid, l_feature_changeset, l_attribute_list, core_utils.json_to_data(i_feature_attributes));
    EXECUTE l_query;

    RETURN l_feature_uuid;
END;
$$;


-- *
-- core_utils.create_feature , used in features/views
-- *
-- CREATE or replace FUNCTION core_utils.create_feature(i_feature_changeset integer, i_feature_point_geometry geometry, i_feature_attributes text)
CREATE or replace FUNCTION core_utils.create_feature(i_webuser_id integer, i_feature_point_geometry geometry, i_feature_attributes text, i_changeset_id integer DEFAULT NULL)
  RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
    l_feature_uuid   uuid;

BEGIN
    l_feature_uuid := core_utils.insert_feature(i_webuser_id, i_feature_point_geometry, i_feature_attributes, NULL, i_changeset_id);

    return l_feature_uuid;
END;
$$;


-- *
-- * core_utils.update_feature, used in attributes/views
-- *
CREATE or replace FUNCTION core_utils.update_feature(i_feature_uuid uuid, i_webuser_id integer, i_feature_point_geometry geometry, i_feature_attributes text, i_changeset_id integer DEFAULT NULL)
  RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
    l_query text;
    l_feature_uuid uuid;
BEGIN

    -- UPDATE: we need to delete data before inserting an updated data row
    l_query := format($qq$DELETE FROM %s WHERE feature_uuid = %L;$qq$, core_utils.const_table_active_data(), i_feature_uuid);
    EXECUTE l_query;

    l_feature_uuid := core_utils.insert_feature(i_webuser_id, i_feature_point_geometry, i_feature_attributes, i_feature_uuid, i_changeset_id);

    -- currently we are relading the page on success so no point on having this call for now
    -- return '{}';
    RETURN core_utils.feature_spec(i_feature_uuid);
END;
$$;


-- *
-- core_utils.get_attributes, used in table reports
-- *


CREATE or replace FUNCTION core_utils.get_attributes()
  RETURNS text
STABLE
LANGUAGE SQL
AS $$
select jsonb_agg(row)::text
FROM
(
    select aa.label, aa.key, aa.result_type, aa.required, aa.searchable, aa.orderable, aa.max_length, aa.min_value, aa.max_value
    from attributes_attribute aa join attributes_attributegroup ag on aa.attribute_group_id = ag.id
    WHERE
        aa.is_active = True
    order by ag.position, aa.position, aa.id
) row;
$$;


-- *
-- * core_utils.get_feature_by_uuid_for_changeset
-- * used in attribute / features

CREATE OR REPLACE FUNCTION core_utils.get_feature_by_uuid_for_changeset(i_uuid UUID, i_changeset_id int default null )
    RETURNS TEXT AS
$BODY$

declare
    l_query text;
    l_result text;
    l_chg text;
begin

    IF i_changeset_id is not null THEN
        l_chg := format('and ad.changeset_id = %s' , i_changeset_id);
    ELSE
        l_chg := format('and ad.changeset_id = (select max(changeset_id) from %s hd WHERE hd.feature_uuid = %L)', core_utils.const_table_history_data(), i_uuid);
    END IF;

    l_query=format($kveri$
        SELECT
            coalesce(jsonb_agg(d.row) :: TEXT, '[]') AS data
        FROM (
            SELECT jsonb_build_object(
                  '_feature_uuid', ad.feature_uuid :: TEXT,
                  '_created_date', chg.ts_created,
                  '_data_captor', wu.email,
                  '_geometry', ARRAY [ST_X(ad.point_geometry), ST_Y(ad.point_geometry)]
                ) || row_to_json(ad.*)::jsonb as row
            FROM
                %s ad -- history_data
            JOIN
                features.changeset chg ON ad.changeset_id = chg.id
            JOIN
                webusers_webuser wu ON chg.webuser_id = wu.id
            WHERE
                ad.feature_uuid = %L
                %s -- changeset condition
            ORDER BY
                ad.ts DESC, ad.feature_uuid
       ) d;
       $kveri$, core_utils.const_table_history_data(), i_uuid, l_chg);

    execute l_query into l_result;

    raise notice '%', l_query;

    return l_result;
end
$BODY$
LANGUAGE plpgSQL
COST 100;



-- *
-- core_utils.get_attribute_history_by_uuid, used in features
-- *

create or replace function
    core_utils.get_attribute_history_by_uuid(i_uuid uuid, attribute_key text, i_start timestamp with time zone, i_end timestamp with time zone)
returns text as
$func$
DECLARE
    l_query text;
    l_result text;
BEGIN

l_query := format(
$$select
    json_agg(row)::text
from (
    SELECT
        hd.ts as ts,
        hd.%I as value
    FROM
        %s hd
    WHERE
        hd.feature_uuid = %L
    and
        hd.ts > %L
    and
        hd.ts <= %L
    order by ts

) row$$, attribute_key, core_utils.const_table_history_data(), i_uuid, i_start, i_end);

    execute l_query into l_result;
    return l_result;
END
$func$
language plpgsql;



-- *
-- * feature by uuid history table | fetch feature history by uuid
-- *
CREATE or replace FUNCTION core_utils.get_feature_history_by_uuid(i_uuid uuid, i_start timestamp with time zone, i_end timestamp with time zone)
  RETURNS text
LANGUAGE plpgsql
AS $$
-- IN:
--     i_uuid uuid representing the feature
--     i_start date, from date
--     i_end date, to date
-- OUT:
--     [
-- {"username":"admin",
-- "email":"admin@example.com",
-- "feature_uuid":"2578c3a6-a306-4756-957a-d1fd92aad1d1","changeset_id":22,"ts":"2017-12-27T00:00:00+01:00"}]

-- select * from core_utils.get_feature_history_by_uuid(
--     '2578c3a6-a306-4756-957a-d1fd92aad1d1',
--     (now() - '6 month'::interval)::date,
--     (now())::date
-- ) as t;

declare
    l_query text;
    l_result text;

begin

l_query=format($kveri$
select
    json_agg(row)::text
from (
    SELECT * from %s hd
    WHERE
        hd.feature_uuid = %L
    and
        hd.ts >= %L
    and
        hd.ts <=  %L
) row;
$kveri$, core_utils.const_table_history_data(), i_uuid, i_start, i_end);

    execute l_query into l_result;

    return l_result;
    end
$$;


-- *
-- * core_utils.get_cluster
-- *
-- * for a point, zoom and desired tile size, calculate center of the cluster
-- *

CREATE OR REPLACE FUNCTION core_utils.get_cluster(i_zoom int, i_tilesize integer, i_min_x float, i_min_y  float, i_point geometry)
  RETURNS geometry
  STABLE
  LANGUAGE plpgsql AS
$$
DECLARE
  l_res float;
BEGIN

    -- only cluster points on low zoom levels
    IF i_zoom <= 12 THEN
      l_res = (180.0 / 256 / 2 ^ i_zoom) * i_tilesize;

      return st_setsrid(ST_SnapToGrid(i_point, i_min_x, i_min_y, l_res, l_res), 4326);
    ELSE
        -- for other (high) zoom levels use real geometry
        return i_point;
    end if;

END;
$$;


-- *
-- * table data report | build export features data to csv query
-- *
CREATE OR REPLACE FUNCTION core_utils.export_all(search_predicate text, i_changeset_id integer default NULL)
    RETURNS TEXT
LANGUAGE plpgsql
AS
$$
DECLARE
    _query      TEXT;
    l_attribute_list TEXT;
    v_query     TEXT;
    l_changeset_predicate TEXT;
    l_table_name TEXT;

BEGIN

    IF i_changeset_id IS NULL
    THEN
        l_changeset_predicate := NULL;
        l_table_name := core_utils.const_table_active_data();
    ELSE
        l_changeset_predicate := format('and history_data.changeset_id = %L', i_changeset_id);
        l_table_name := core_utils.const_table_history_data();
    END IF;

    v_query:= $attributes$
    select
        string_agg(quote_ident(key), ', ' ORDER BY row_number) as attribute_list
    from (
        SELECT row_number() OVER (ORDER BY
            ag.position, aa.position), aa.key
        FROM
            attributes_attribute aa JOIN attributes_attributegroup ag on aa.attribute_group_id = ag.id
        WHERE
            aa.is_active = True
    ) d;
    $attributes$;

    EXECUTE v_query INTO l_attribute_list;

    _query:= format($qveri$COPY (
    select feature_uuid, email, changeset_id as changeset, ts, %s from %s %s %s
    ) TO STDOUT WITH CSV HEADER$qveri$, l_attribute_list, l_table_name, search_predicate, l_changeset_predicate);

    RETURN _query;

END
$$;


-- * ==================================
-- * ACTIVE_DATA MANIPULATION
-- * ==================================

-- *
-- * DROP attributes attribute column active_data
-- *
CREATE OR REPLACE FUNCTION core_utils.drop_active_data_column(i_old ATTRIBUTES_ATTRIBUTE)
    RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_query      TEXT;
BEGIN
    v_query := format($deactivate$
    UPDATE attributes_attribute SET is_active = False WHERE key = %L
$deactivate$, i_old.key);

    EXECUTE v_query;
END
$$;


-- *
-- * Add attributes attribute column active_data
-- *
create or replace function core_utils.add_active_data_column(i_new ATTRIBUTES_ATTRIBUTE)
   RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_query TEXT;
    l_attribute_type text;
    l_field_name text;
BEGIN

  select
      case
          when i_new.result_type = 'Integer' THEN 'int'
          when i_new.result_type = 'Decimal' THEN 'numeric(17, 8)'
          when i_new.result_type = 'Text' THEN 'text'
          when i_new.result_type = 'DropDown' THEN 'text'
          ELSE null
      end as val,
      i_new.key as field_name
  into
    l_attribute_type, l_field_name;

  v_query:= format($alter$
      alter table %s add column %s %s;
  $alter$, core_utils.const_table_active_data(), l_field_name, l_attribute_type);
  execute v_query;

  v_query:= format($alter$
      alter table %s add column %s %s;
  $alter$, core_utils.const_table_history_data(), l_field_name, l_attribute_type);
  execute v_query;

end
$$;



-- * attributes_attribute RULES to handle active_data table
-- * Add or Drop on delete or on insert RULE on atrributes_attribute table
-- * i_action: create | drop
CREATE OR REPLACE FUNCTION core_utils.attribute_rules(i_action text)
    RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    l_query      TEXT;
BEGIN


    if i_action = 'create' then
        -- * ADD ON ATTRIBUTE DELETE RULE
        l_query:='CREATE OR REPLACE RULE
            drop_active_data_field_rule AS
        ON delete TO
            public.attributes_attribute
        DO INSTEAD
            select core_utils.drop_active_data_column(OLD)';

        RAISE NOTICE 'On delete Rule: %', l_query;

        execute l_query;

        -- * ADD ON ATTRIBUTE INSERT RULE
        l_query:='CREATE OR REPLACE RULE
            active_data_add_field_rule AS
        ON INSERT TO
            public.attributes_attribute
        DO ALSO
            SELECT core_utils.add_active_data_column(NEW)';

        RAISE NOTICE 'On INSERT Rule: %', l_query;

        execute l_query;

        -- UPDATE ON ATTRIBUTE update RULE for active data
        -- DO NOT ADD ANY ON UPDATE RULE - we pivot the table so n -> 1
        -- update active data manually when all fields are inserted / updated

    ELSEIF i_action = 'drop' then

        DROP RULE if exists drop_active_data_field_rule ON public.attributes_attribute;
        DROP RULE if exists active_data_add_field_rule ON public.attributes_attribute;
    END IF;

END
$$;


-- *
-- * core_utils.json_to_data - transform data form serialized as json to active_data columns
-- *

create or replace function core_utils.json_to_data(i_raw_json text)
    RETURNS text
LANGUAGE plpgsql
AS $func$
DECLARE
  l_attribute_converters text[];
  l_key text;
  l_type text;
  l_json json;
BEGIN
  l_json := cast(i_raw_json as json);

  FOR l_key, l_type IN (SELECT
    aa.key,
    aa.result_type
  FROM
    attributes_attribute aa
    JOIN attributes_attributegroup ag on aa.attribute_group_id = ag.id
    WHERE is_active = True
  ORDER BY
    ag.position, aa.position) LOOP

    IF l_type = 'Integer' THEN
      l_attribute_converters := array_append(l_attribute_converters, format($$cast(%L as integer) as %I$$, l_json ->> l_key, l_key));
    elseif l_type = 'Decimal' THEN
      l_attribute_converters := array_append(l_attribute_converters, format($$cast(%L as numeric(17, 8)) as %I$$, l_json ->> l_key, l_key));
    ELSEif l_type = 'DropDown' THEN
      l_attribute_converters := array_append(l_attribute_converters, format($$
      coalesce(
        (
            select
                ao.option
            FROM attributes_attributeoption ao JOIN attributes_attribute aa ON ao.attribute_id = aa.id
            WHERE ao.option = %L AND aa.key = %L AND aa.is_active = True
        )
      , 'Unknown') as %I
$$, l_json ->> l_key, l_key, l_key));
    ELSE
      l_attribute_converters := array_append(l_attribute_converters, format($$%L as %I$$, l_json ->> l_key, l_key));
    end if;

  end loop;

  RETURN array_to_string(l_attribute_converters, ', ');

  END;
$func$;


CREATE or replace FUNCTION core_utils.filter_attribute_options(attribute_key text, option_search_str text)
  RETURNS text
STABLE
LANGUAGE SQL
AS $$
-- Filter attribute options by attribute key and options key
--
-- select * from core_utils.filter_attribute_options('tabiya', 'selam');
-- {
--   "attribute_id": 3,
--   "attribute_key": "tabiya",
--   "attribute_group_id": 1,
--   "attribute_group_key": "location_description",
--   "attribute_group_label": "Location description",
--   "attribute_options": [
--     {
--       "option_id": 635,
--       "option": "Selam-Bkalsi"
--     },
--     {
--       "option_id": 634,
--       "option": "Selam-Bikalsi"
--     }...
--   ]
-- }
SELECT
  json_build_object(
    'attribute_id', aa.id ,
    'attribute_key', aa.key,
--     'attribute_group_id', ag.id,
--     'attribute_group_key', ag.key,
--     'attribute_group_label', ag.label,
    'attribute_options', json_agg(
        json_build_object(
            'option_value', ao.value ,
            'option', ao.option)
        )
    )::text
    FROM
        attributes_attribute aa
    JOIN
        attributes_attributegroup ag
    ON
        aa.attribute_group_id = ag.id
    LEFT JOIN
        attributes_attributeoption ao
    ON
        ao.attribute_id = aa.id
    where
      aa.key = $1
    and
      ao.option ilike '%' || $2 || '%'
    group by
      aa.id,
      aa.key;
--       ag.id,
--       ag.key,
--       ag.label

$$;



-- *
-- * Create data cache table (active_data_table) based on attributes_attribute table columns
-- * ADD index
-- * core_utils.create_dashboard_cache_table (active_data)
-- *

CREATE or replace function core_utils.create_dashboard_cache_table (i_table_name varchar) returns void as

$func$
DECLARE
    l_relation_name     text;
    l_query             text;
    l_fields            text;
    l_default_fields    text;
    l_calculated_fields text;
BEGIN
    -- until otherwise needed leave hardcoded
    l_default_fields:='point_geometry geometry, email varchar, ts timestamp with time zone, feature_uuid uuid, changeset_id int';
    l_calculated_fields='static_water_level_group_id int, amount_of_deposited_group_id int, yield_group_id int';

    l_query:=$fields$select
                string_agg((aa.key || ' ' ||
                case
                    when aa.result_type = 'Integer' THEN 'int'
                    when aa.result_type = 'Decimal' THEN 'numeric(17, 8)'
                    when aa.result_type = 'Text' THEN 'text'
                    when aa.result_type = 'DropDown' THEN 'text'
                    ELSE null
                end), ', ')
            from
                attributes_attribute aa$fields$;

        execute l_query into l_fields;

    l_query := 'create table if not exists '|| i_table_name ||' (' ||  l_default_fields || ',' || l_fields || ',' || l_calculated_fields || ');';

    execute l_query;

    -- create indexes for cache tables
    l_relation_name := split_part(i_table_name, '.', 2);

    l_query := format(
        $$CREATE UNIQUE INDEX %s_feature_uuid_changeset_id_uidx ON %s (feature_uuid, changeset_id DESC);$$,
        l_relation_name, i_table_name
    );
    execute l_query;
    l_query := format(
        $$CREATE INDEX %s_feature_uuid_ts_idx ON %s (feature_uuid, ts DESC);$$,
        l_relation_name, i_table_name
    );
    execute l_query;

    l_query := format(
        $$CREATE INDEX %s_point_geometry_idx ON %s USING GIST (point_geometry);$$,
        l_relation_name, i_table_name
    );
    execute l_query;

END
$func$ LANGUAGE plpgsql;



-- *
-- * core_utils.feature_spec - returns full feature specification for a feature_uuid, 'feature_data', 'attributes_attribute', 'attributes_group'
-- *

create or replace function core_utils.feature_spec(i_feature_uuid uuid)
RETURNS text
LANGUAGE plpgsql
AS $func$
-- test
-- select core_utils.feature_spec('fa3337aa-2728-4f2e-8c90-20bdd0d2ee33');

DECLARE
    l_query text;
    l_result text;
    l_attribute_list text;
    l_exists boolean;
BEGIN

    l_query := format($$select true from %s WHERE feature_uuid = %L$$, core_utils.const_table_active_data(), i_feature_uuid);

    EXECUTE l_query into l_exists;
    IF l_exists is null THEN
        return '{}';
    end if;

    l_query := $attributes$
    select
        string_agg(quote_ident(key), ', ' ORDER BY row_number) as attribute_list
    from (
        SELECT row_number() OVER (ORDER BY
            ag.position, aa.position), aa.key
        FROM
            attributes_attribute aa JOIN attributes_attributegroup ag on aa.attribute_group_id = ag.id
        WHERE
            aa.is_active = True
    ) d;
    $attributes$;

    EXECUTE l_query INTO l_attribute_list;

    l_query := format($query$select jsonb_build_object(
    'attribute_groups',
      (select jsonb_object_agg(key, row_to_json(row.*)) from (
        select key, label, position from public.attributes_attributegroup order by position
      ) row),
    'attribute_attributes',
      (select json_object_agg(key, row_to_json(row.*))
from (
     select
            aa.key,
            aa.label,
            jsonb_build_object(
              'result_type', aa.result_type,
              'orderable', aa.orderable,
              'searchable', aa.searchable
            ) as meta,
            jsonb_build_object(
              'required', aa.required,
                'max_length', aa.max_length,
                'min_value', aa.min_value,
                'max_value', aa.max_value
            ) as validation,
            ag.key as attribute_group,
            aa.position
      from
          attributes_attribute aa
          JOIN attributes_attributegroup ag on aa.attribute_group_id = ag.id
      where aa.is_active = true
      order by ag.position, aa.position, aa.id
) row),
    'feature_data',
      (select row_to_json(row) from (
        select %s
        from
        %s
        where feature_uuid = %L
      ) row)
    )::text;$query$, l_attribute_list, core_utils.const_table_active_data(), i_feature_uuid);

    execute l_query into l_result;

    return l_result;

  END;
$func$;
