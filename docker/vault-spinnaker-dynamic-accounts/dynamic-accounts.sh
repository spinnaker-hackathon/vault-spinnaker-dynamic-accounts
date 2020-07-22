#!/bin/bash

die() { echo "$*" 1>&2 ; exit 1; }

if [ -z "$VAULT_DYNAMIC_ACCOUNT_SECRET_LOCATION" ]; then
    die "Need vault dynamic account secret location VAULT_DYNAMIC_ACCOUNT_SECRET_LOCATION to continue"
fi

if [ -z "$VAULT_INTAKE_ACCOUNT_SECRET_LOCATION" ]; then
    die "Need vault intake account secret location VAULT_INTAKE_ACCOUNT_SECRET_LOCATION to continue"
fi
