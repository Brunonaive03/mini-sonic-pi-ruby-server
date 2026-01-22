# Mini Sonic Pi PT-BR: Interpretador Musical (Backend)

Este repositório contém o core interpretador e o backend da aplicação **Mini Sonic Pi PT-BR**. O projeto consiste na localização de uma DSL (Domain-Specific Language) musical para o português brasileiro, visando reduzir a carga cognitiva de usuários lusófonos durante o aprendizado de programação musical.

Este trabalho é parte integrante do Trabalho de Conclusão de Curso (TCC) em Ciência da Computação na **Universidade Federal de Pernambuco (UFPE)**.

---

## 🚀 Sobre o Projeto

A proposta principal é investigar como a tradução de comandos e a adaptação sintática de linguagens de programação musical podem facilitar o acesso à computação criativa. O backend, desenvolvido em **Ruby**, atua como o motor de processamento que recebe, valida e interpreta os comandos localizados.

### Principais Funcionalidades

* **Processamento de DSL Localizada:** Interpretação de comandos musicais em português brasileiro.
* **Arquitetura Dockerizada:** Ambiente isolado e reprodutível para facilitar o deploy e o desenvolvimento.
* **Integração com Ecossistema:** Pronto para se comunicar com um frontend em React e um serviço de coleta de dados em Python.

---

## 🛠️ Tecnologias Utilizadas

* **Linguagem:** [Ruby](https://www.ruby-lang.org/) (Sintaxe limpa e ideal para criação de DSLs internas).
* **Ambiente:** [Docker](https://www.docker.com/) & Docker Compose.
* **Testes:** [RSpec](https://rspec.info/) para validação da lógica de tradução e execução.

---

## 🏗️ Arquitetura do Sistema

O backend Ruby funciona como um serviço dentro de uma arquitetura composta por três camadas:

1. **Frontend (ReactJS):** Interface de usuário e síntese de áudio via Web Audio API.
2. **Backend Ruby (Este repositório):** Motor de interpretação da linguagem.
3. **Serviço de Dados (Python/MongoDB):** Persistência de logs e métricas para análise da pesquisa acadêmica.

---

## 📜 Ética e Créditos

Este projeto é uma implementação independente desenvolvida para fins de pesquisa acadêmica.

* **Inspiração:** O design da linguagem e o comportamento dos comandos são inspirados no [Sonic Pi](https://sonic-pi.net/), criado pelo **Dr. Sam Aaron**.
* **Originalidade:** Não houve cópia ou redistribuição de código-fonte do projeto original. Trata-se de uma reconstrução focada no estudo de localização e **Teoria da Carga Cognitiva**.
* **Licença:** Este projeto está sob a licença MIT.

---

## 🎓 Contexto Acadêmico

* **Instituição:** Centro de Informática (CIn) - UFPE.
* **Autor:** Bruno Lima.
* **Tema:** Localização de DSLs musicais para o português brasileiro como forma de acessibilidade cognitiva.
* **Metodologia:** O desenvolvimento segue os princípios da *Design Science Research Methodology* (DSRM).