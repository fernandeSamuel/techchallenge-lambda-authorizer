# 💡 Introdução

## Objetivo ##
Este repositório contém uma estrutura de arquivos `hcl` para o provisionamento de infraestrutura na AWS. Esta arquitetura é composta pelo API Gateway, Lambda e S3 organizados em um módulo distinto para facilitar a manutenção e escalabilidade.

## 📦 Estrutura ##

- *serverless:* Provisionamento de toda a arquitetura serverless responsável pela autenticação do cliente.

### Pré-requisitos

- *AWS CLI:* Configurado com um perfil para autenticação.
- *Terraform:* Certifique-se de que a versão instalada seja compatível com os provedores declarados (~> 4.0).

### Configuração Inicial

- *Configurar o AWS CLI:* Execute ´aws configure´ e configure o perfil de autenticação com as credenciais apropriadas para provisionar a infraestrutura na região ´us-east-1´ juntamente com uma *access_key* e uma *secret_key*.
- *Configurar o backend do Terraform:* A pasta ´rds´ possui um backend remoto cujo state é salvo em um Workspace do Terraform Cloud, por isso é necessário em execuções locais executar o [Terraform Login](https://developer.hashicorp.com/terraform/tutorials/cloud-get-started/cloud-login#start-the-login-flow).

## Como Provisionar Recursos ##

### Configuração Serverless

Acesse e execute os seguintes comandos na pasta `serverless:`

```bash
terraform init
terraform apply

```

Isso irá inicializar todo o backend do Terraform e criar os componentes Servelress necessário para realizar a autenticação e se integrar com o restante da estrutura.

## Licença
Este projeto é licenciado sob os termos da MIT License.
