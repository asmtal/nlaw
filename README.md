# Москаль, иди нахуй

```shell
# Як лупанути кацапів?
# реєструйся в aws cloud 
# Качай terraform https://www.terraform.io/downloads

cp terraform.tfvars.sample terraform.tfvars

# Міняй terraform.tfvars
terraform init

# Обирай регіон
terraform workspace new <aws region> # e.g. eu-west-3
terraform plan -out tfplan

# Лупи
terraform apply tfplan
```