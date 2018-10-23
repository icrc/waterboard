from django import forms
from django.forms import ModelForm

from .models import Task


class UploadFileForm(ModelForm):
    """Form for uploading file with data."""

    class Meta:
        model = Task
        fields = ('file',)


class ImportDataForm(forms.Form):
    """Form for inserting data from uploaded file."""
