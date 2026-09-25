from django.contrib import admin
from django.http import HttpResponse
from django.urls import path


def home(_request):
    return HttpResponse(
        '<!DOCTYPE html>'
        '<html><head><title>Django Base</title></head>'
        '<body style="font-family: system-ui; max-width: 40rem; margin: 4rem auto;">'
        '<h1>Django base is running</h1>'
        '<p>Edit files on the host — the volume mount picks up changes.</p>'
        '<p><a href="/admin/">Admin</a></p>'
        '</body></html>'
    )


urlpatterns = [
    path('admin/', admin.site.urls),
    path('', home, name='home'),
]
