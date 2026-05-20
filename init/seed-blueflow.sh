#!/bin/bash
# Provisions the BlueFlow admin user and API token from env vars.
# Called via: docker compose exec blueflow bash /demo-init/seed-blueflow.sh
set -eu

cd /app
.venv/bin/python project/manage.py shell -c "
from django.contrib.auth import get_user_model
from rest_framework.authtoken.models import Token
from waffle.models import Switch
import os

User = get_user_model()
username = os.environ.get('DEFAULT_USERNAME', 'admin')
password  = os.environ.get('DEFAULT_PASSWORD', 'admin')
token_val = os.environ['API_TOKEN']

user, _ = User.objects.get_or_create(
    username=username,
    defaults={'is_superuser': True, 'is_staff': True},
)
user.set_password(password)
user.save()

token, created = Token.objects.get_or_create(user=user, defaults={'key': token_val})
if not created and token.key != token_val:
    token.key = token_val
    token.save()

# Enable the 'core' waffle switch required by AssetViewSet (and likely other viewsets)
Switch.objects.get_or_create(name='core', defaults={'active': True})

print('BlueFlow seed complete. Token:', token_val[:8] + '...')
"
