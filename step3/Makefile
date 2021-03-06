ADDITIONAL_ARGS=-var 'traefik_api_key=$(TRAEFIK_API_KEY)' -var "github_user=$(GH_USER)" -var "github_pat=$(GH_TOKEN)"

apply:
	cd infrastructure; terraform apply $(ADDITIONAL_ARGS) -auto-approve -var-file ../variables.tfvars

plan:
	cd infrastructure; terraform plan $(ADDITIONAL_ARGS) -var-file ../variables.tfvars

destroy:
	cd infrastructure; terraform destroy $(ADDITIONAL_ARGS) -var-file ../variables.tfvars

refresh:
	cd infrastructure; terraform refresh $(ADDITIONAL_ARGS) -var-file ../variables.tfvars

init:
	cd infrastructure; rm -fr .terraform; terraform init

import:
	cd infrastructure; terraform import $(ADDITIONAL_ARGS) -var-file ../variables.tfvars $(ARGS)

lint:
	terraform fmt -recursive infrastructure/