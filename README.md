# Confluent Cloud for Apache Flink (CCAF) Tableflow Snowflake Kickstarter

Data practitioners are entering a golden era—a time defined by groundbreaking possibilities and transformative innovation. In the early days, building data warehouses demanded colossal intellectual and financial investments. We painstakingly engineered and maintained limited conforming dimensions and facts, continuously adapting to meet evolving business needs. Copying data from source to target not only came at a high cost but also stripped away vital context, which had to be painstakingly rebuilt to extract actionable insights.

As we evolved to data lakes, many challenges persisted: maintenance overhead, slow adaptability to surging data demands, and the constant struggle to preserve context. Now, with the burgeoning tide of ML and AI, the stakes have escalated even further. Yet, these very challenges are paving the way for unprecedented opportunities for innovation and efficiency. Today, every obstacle serves as a stepping stone toward a more agile, insightful, and future-ready data landscape.

On [March 19, 2025](https://docs.confluent.io/cloud/current/release-notes/index.html#march-19-2025), Confluent proudly announced the general availability of [Tableflow for Apache Iceberg](https://docs.confluent.io/cloud/current/topics/tableflow/overview.html#cloud-tableflow), marking a transformative milestone for data warehousing and data lakes. This monumental release redefines data management by seamlessly addressing the complexities of modern data infrastructures. Leveraging the unparalleled power of our fully managed open-source trifecta—Apache Kafka, Apache Flink, and Apache Iceberg—we now deliver a unified solution that adeptly serves both operational and analytics data needs.

Welcome to the forefront of the data revolution, where every challenge is an opportunity and innovation knows no bounds.

<!-- toc -->
+ [**1.0 Kickoff**](#10-kickoff)
    - [**1.1 DevOps in Action: Running Terraform Locally**](#11-devops-in-action-running-terraform-locally)
        + [**1.1.1 Run locally**](#111-run-locally)
    - [**1.2 Visualizing the Terraform Configuration**](#12-visualizing-the-terraform-configuration)
+ [**2.0 Resources**](#20-resources)
    - [**2.1 Confluent Cloud for Apache Flink (CCAF)**](#21-confluent-cloud-for-apache-flink-ccaf)
    - [**2.2 Tableflow for Apache Iceberg**](#22-tableflow-for-apache-iceberg)
    - [**2.3 Snowflake**](#23-snowflake)
+ [**3.0 Important Note(s)**](#30-important-notes)
<!-- tocstop -->

## 1.0 Kickoff

**These are the steps**

1. Take care of the cloud and local environment prequisities listed below:
    > You need to have the following cloud accounts:
    > - [AWS Account](https://signin.aws.amazon.com/) *with SSO configured*
    > - [Confluent Cloud Account](https://confluent.cloud/)
    > - [Snowflake Account](https://app.snowflake.com/)
    > - [Terraform Cloud Account](https://app.terraform.io/)

    > You need to have the following installed on your local machine:
    > - [AWS CLI version 2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
    > - [Confluent CLI version 4 or higher](https://docs.confluent.io/confluent-cli/4.0/overview.html)
    > - [Terraform CLI version 1.11.4 or higher](https://developer.hashicorp.com/terraform/install)

2. Clone the repo:
    ```bash
    git clone https://github.com/j3-signalroom/ccaf-tableflow-snowflake-kickstarter.git
    ```

3. Set up your Terraform Cloud environment locally. Here's what you can expect:

    - A Confluent Cloud environment featuring a Kafka Cluster, fully equipped with pre-configured example Kafka topics—ready to power your data streaming needs.

    - AWS Secrets Manager securely storing API Key Secrets for the Kafka Cluster.

    - An AWS S3 bucket with a dedicated `warehouse` folder, serving as the landing zone for Apache Iceberg Tables populated by two Python-based Flink apps, bringing your data streaming architecture to life.

With these steps, you'll have everything set up to run enterprise-grade data streaming applications in no time!

### 1.1 DevOps in Action: Running Terraform Locally
Install the [Terraform CLI](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) on your local machine, and make sure you have an [HCP Terraform account](https://app.terraform.io/session) to run the Terraform configuration.  Learn how to set up Terraform Cloud for local use by clicking [here](.blog/setup-terraform-cloud.md).

#### 1.1.1 Run locally
```bash
deploy-terraform-locally.sh <create | delete> --profile=<SSO_PROFILE_NAME> \
                                              --confluent-api-key=<CONFLUENT_API_KEY> \
                                              --confluent-api-secret=<CONFLUENT_API_SECRET> \
                                              --snowflake-warehouse=<SNOWFLAKE_WAREHOUSE> \
                                              --day-count=<DAY_COUNT> \
                                              --auto-offset-reset=<earliest | latest> \
                                              --number-of-api-keys-to-retain=<NUMBER_OF_API_KEYS_TO_RETAIN>
```
> Argument placeholder|Replace with
> -|-
> `<SSO_PROFILE_NAME>`|your AWS SSO profile name for your AWS infrastructue that host your AWS Secrets Manager.
> `<CONFLUENT_API_KEY>`|your organization's Confluent Cloud API Key (also referred as Cloud API ID).
> `<CONFLUENT_API_SECRET>`|your organization's Confluent Cloud API Secret.
> `<SNOWFLAKE_WAREHOUSE>`|the Snowflake warehouse (or "virtual warehouse") you choose to run the resources in Snowflake.
> `<DAY_COUNT>`|how many day(s) should the API Key be rotated for.
> `<AUTO_OFFSET_RESET>`|Use `earliest`, when you want to read the first event in a Kafka topic.  Otherwise, specify `latest`.
> `<NUMBER_OF_API_KEYS_TO_RETAIN>`|Specifies the number of API keys to create and retain.

To learn more about this script, click [here](.blog/deploy-terraform-locally-script-explanation.md).

### 1.2 Visualizing the Terraform Configuration
Below is the Terraform visualization of the Terraform configuration. It shows the resources and their dependencies, making the infrastructure setup easier to understand.

![Terraform Visulization](.blog/images/terraform-visualization.png)

> **To fully view the image, open it in another tab on your browser to zoom in.**

When you update the Terraform Configuration, to update the Terraform visualization, use the [`terraform graph`](https://developer.hashicorp.com/terraform/cli/commands/graph) command with [Graphviz](https://graphviz.org/) to generate a visual representation of the resources and their dependencies.  To do this, run the following command:

```bash
terraform graph | dot -Tpng > .blog/images/terraform-visualization.png
```

## 2.0 Resources
* [Shift Left: Unifying Operations and Analytics With Data Products eBook](https://www.confluent.io/resources/ebook/unifying-operations-analytics-with-data-products/?utm_medium=sem&utm_source=google&utm_campaign=ch.sem_br.nonbrand_tp.prs_tgt.dsa_mt.dsa_rgn.namer_lng.eng_dv.all_con.resources&utm_term=&creative=&device=c&placement=&gad_source=1&gad_campaignid=12131734288&gbraid=0AAAAADRv2c3NnjtbB2EmbR4ZfsjGY1Uge&gclid=EAIaIQobChMIm5KUs7GhjQMVQDUIBR0YgAilEAAYASAAEgKu8_D_BwE)


### 2.1 Confluent Cloud for Apache Flink (CCAF)
* [Stream Processing with Confluent Cloud for Apache Flink](https://docs.confluent.io/cloud/current/flink/overview.html#stream-processing-with-af-long)

### 2.2 Tableflow for Apache Iceberg
* [Tableflow in Confluent Cloud](https://docs.confluent.io/cloud/current/topics/tableflow/overview.html#cloud-tableflow)
* [Terraforming Snowflake](https://quickstarts.snowflake.com/guide/terraforming_snowflake/index.html?index=..%2F..index&utm_cta=website-workload-cortex-timely-content-copilot-ama#0)

### 2.3 Snowflake
* [Snowflake Create Storage Integration](https://docs.snowflake.com/en/sql-reference/sql/create-storage-integration)

## 3.0 Important Note(s)
* [Known Issue(s)](KNOWNISSUES.md)