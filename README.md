# POS TECH - Tech Challenge: Sistema de Gestão de Oficina Mecânica

Este repositório contém os scripts de provisionamento da infraestrutura necessária para o backend do **Sistema Integrado de Atendimento e Execução de Serviços** de uma oficina mecânica. O projeto foi desenvolvido como parte do "Tech Challenge" da pós-graduação POS TECH, com o objetivo de solucionar os desafios de desorganização e ineficiência enfrentados pela oficina.

O sistema foi modelado utilizando a metodologia **Domain-Driven Design (DDD)**, com um foco especial no ciclo de vida da Ordem de Serviço (OS) e suas transições de status. A aplicação é um back-end **monolítico** desenvolvido em **Java 21** e **Spring Boot**, expondo suas funcionalidades através de APIs **RESTful**.

O foco deste repositório é prover toda a estrutura necessária para manter a aplicação principal fluída e segura, aplicando boas práticas de **Provisionamento de infraestrutura**, **Gestão de Recursos** e **Segurança**. Isso inclui a gestão de chaves e informações privadas utilizando **Secret Manager**, **Horizontal Pod AutoScaler**, **HELM** e **Load Balancer**, todas ferramentas disponibilizadas pela AWS.

### Infraestrutura e Recursos da AWS

* **DynamoDB e S3:** Serviços utilizados para gerenciar os arquivos de estado da infraestrutura (.tfstate).
* **EKS:** Serviço de gerenciamento do serviços do Kubernetes
* **ECR:** Serviço de armazenamento da imagem Docker da aplicação.
* **Ingress:** Serviço de gerenciamento de acesso externo aos serviços no cluster.
* **HPA:** Serviço de gerenciamento de escalabilidade da aplicação baseado em seu uso (memória ou uso de CPU).
* **Secret Manager:** Serviço de gerenciamento de senhas e dados sensíveis ao cluster.


#### 1. Provisionando a Infraestrutura com Terraform na AWS

Esta seção descreve como utilizar o Terraform para provisionar toda a infraestrutura necessária para o projeto na AWS.

1.  **Dependências do Projeto:** Certifique-se de que todos os pré-requisitos da seção anterior estejam devidamente instalados.

2.  **Instalação do Terraform:** É necessário ter o Terraform instalado em sua máquina. Siga as instruções de instalação no [site oficial da HashiCorp](https://developer.hashicorp.com/terraform/install).

#### Passos para Execução

1. **Vá ate o caminho: `./tf/_backend/`**, e execute o comando:
   ```bash
   terraform init
    ```
    * Comando para inicializar o ambiente e preparar a infraestrutura necessária para ser provisionada.

2.  Em seguida, execute o seguinte comando para inicializar o DynamoDB e o S3:
    ```bash
    terraform apply
    ```
    * Utilize a flag -auto-approve, caso não queira revisar o plano de execução antes de aprová-lo para execução.

3. Na sequência, **vá até `./tf/dev/`**, para iniciar a infraestrutura do cluster da aplicação:
    ```bash
    terraform init
    ```
4. Após a preparação do ambiente, a estrutura pode ser inicializada e provisionada:
    ```bash
    terraform apply
    ```
    * -auto-approve.

5. Com esses passos a infraestrutura planejada vai ser provisionada e garantir que a aplicação pode ser deployada.

6. Caso, queira validar a infraestrutura gerada, pode consultar pelo console de cluster na AWS (EKS), que o cluster já deverá estar criado.

#### Destruindo a Infraestrutura

Para remover todos os recursos criados pelo Terraform nesta configuração, utilize o comando abaixo. Ele também exibirá um plano de destruição e pedirá sua confirmação antes de prosseguir.

**Atenção:** Este comando é destrutivo e irá apagar permanentemente a infraestrutura gerenciada. Use com cuidado.
```bash
terraform apply
```
* Lembre de executar o comando tanto para a pasta `/_backend`, como para `/dev`
