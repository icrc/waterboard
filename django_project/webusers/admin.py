# -*- coding: utf-8 -*-
from __future__ import absolute_import, division, print_function, unicode_literals

from django import forms
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth.forms import ReadOnlyPasswordHashField
from django.contrib.gis import admin

from .models import WebUser


"""
Most helpful article:

http://thepythondjango.com/creating-custom-user-model-and-custom-authentication-in-django/
"""


class UserCreationForm(forms.ModelForm):
    # A form for creating new users. Includes all the required
    # fields, plus a repeated password.
    password1 = forms.CharField(label='Password', widget=forms.PasswordInput)
    password2 = forms.CharField(label='Password confirmation', widget=forms.PasswordInput)

    class Meta:
        model = WebUser
        fields = ('email', 'full_name')

    def clean_password2(self):
        # Check that the two password entries match
        password1 = self.cleaned_data.get('password1')
        password2 = self.cleaned_data.get('password2')
        if password1 and password2 and password1 != password2:
            raise forms.ValidationError('Passwords don\'t match')
        return password2

    def save(self, commit=True):
        # Save the provided password in hashed format
        user = super(UserCreationForm, self).save(commit=False)
        user.set_password(self.cleaned_data['password1'])
        if commit:
            user.save()
        return user


class UserChangeForm(forms.ModelForm):
    # A form for updating users. Includes all the fields on
    # the user, but replaces the password field with admin's
    # password hash display field.

    password = ReadOnlyPasswordHashField(
        label='Password',
        help_text=(
            'Raw passwords are not stored, so there is no way to see this '
            'user\'s password, but you can change the password using '
            '<a href="../password/">this form</a>.'
        ),
    )

    class Meta:
        model = WebUser
        fields = ('email', 'full_name', 'password', 'is_active', 'is_staff')

    def clean_password(self):
        # Regardless of what the user provides, return the initial value.
        # This is done here, rather than on the field, because the
        # field does not have access to the initial value
        return self.initial['password']


class UserAdmin(BaseUserAdmin, admin.OSMGeoAdmin):
    # The forms to add and change user instances
    form = UserChangeForm
    add_form = UserCreationForm

    # The fields to be used in displaying the User model.
    # These override the definitions on the base UserAdmin
    # that reference specific fields on auth.User.
    list_display = ('email', 'is_active', 'is_staff')
    list_filter = ('email',)
    fieldsets = (
        (None, {'fields': ('email', 'full_name', 'password', 'geofence')}),
        ('Permissions', {'fields': ('is_active', 'is_staff',)}),
    )
    # add_fieldsets is not a standard ModelAdmin attribute. UserAdmin
    # overrides get_fieldsets to use this attribute when creating a user.
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('email', 'full_name', 'password1', 'password2', 'geofence')}),
    )
    search_fields = ('email',)
    ordering = ('email',)
    filter_horizontal = ()

    # add OsmGeoAdmin properties
    default_zoom = 7
    default_lon = 4383204
    default_lat = 1431064


admin.site.register(WebUser, UserAdmin)