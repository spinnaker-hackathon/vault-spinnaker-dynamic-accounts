FROM devorbitus/docker-vault-jq:latest

COPY dynamic-accounts.sh .

RUN ["chmod", "+x", "./dynamic-accounts.sh"]

ENTRYPOINT [ "./dynamic-accounts.sh" ]
