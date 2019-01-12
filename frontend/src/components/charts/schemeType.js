/**
 * SchemeType "chart"
 *
 * Example: Pattern used for reusable d3 charts
 *
 * @returns {chart}
 */

let _data = {};
let _updateChartFn;


const _updateChart = (element) => {
    element.innerHTML =  Object.keys(_data)
        .sort()
        .map(function (value) {
            return _createInfoRow(value, {
                'beneficiaries': _.get(_data, `${value}.total_beneficiaries`, '*'),
                'features': _.get(_data, `${value}.total_features`, '-')
            });
        })
      .join('');
};


const _createInfoRow = (label, opts) => {
    let {
        beneficiaries,
        features
    } = opts;

    return `<div class="info-row">
        <div class="info-row-label">${label}</div>
            <div class="info-statistics">
                <div class="main-nmbr">${beneficiaries ||  ' - ' }</div>
                <div class="other-nmbr">${features ||  ' - ' }</div>
        </div>
    </div>`;
};

const createUpdateChartFn = (element) => {
    return () => {
        _updateChart(element);
    }
};

const chart = (parentDom) => {

    const infoWrapper = document.createElement('div');

    infoWrapper.setAttribute('class', 'wb-schemetype-chart');

    parentDom.appendChild(infoWrapper);

    _updateChartFn = createUpdateChartFn(infoWrapper);

    // update the chart
    _updateChartFn();
};

chart.data = (value = {}) => {
    _data = value;

    if (typeof _updateChartFn === 'function') {
        _updateChartFn();
    }

    return chart;
};


const chartInit = (parentDom) => {
    chart(parentDom);
    return chart;
};

export default chartInit;
