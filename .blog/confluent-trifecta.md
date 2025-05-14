# Confluent Trifecta: Kafka ✨ Flink ✨ Iceberg
Data practitioners are entering a golden era-a time defined by groundbreaking possibilities and transformative innovation. In the early days, building data warehouses required enormous intellectual and financial investments. We carefully engineered and maintained limited conforming dimensions and facts, continuously adapting to meet evolving business needs. Transferring data from source to target not only incurred high costs but also stripped away vital context, which had to be painstakingly rebuilt to derive actionable insights.

As we evolved to data lakes, many challenges persisted: maintenance overhead, slow adaptability to surging data demands, and the constant struggle to preserve context. With the burgeoning tide of ML and AI, the stakes have escalated even further. Yet, these challenges are paving the way for unprecedented opportunities for innovation and efficiency. Today, every obstacle is a stepping stone toward a more agile, insightful, and future-ready data landscape.

On [March 19, 2025](https://docs.confluent.io/cloud/current/release-notes/index.html#march-19-2025), Confluent proudly announced the general availability of [Tableflow for Apache Iceberg](https://docs.confluent.io/cloud/current/topics/tableflow/overview.html#cloud-tableflow), marking a transformative milestone for data warehousing and data lakes. This monumental release redefines data management by seamlessly addressing the complexities of modern data infrastructures. Leveraging the unparalleled power of our fully managed open-source trifecta—Apache Kafka, Apache Flink, and Apache Iceberg—we now deliver a unified solution that adeptly serves both operational and analytical data needs.

![this-is-us-sterling-k-brown](images/this-is-us-sterling-k-brown.gif)

Welcome to the forefront of the data revolution, where every challenge is an opportunity and innovation knows no bounds.

## Load down on Tableflow


### Storage option should you pick?

Confluent has supports two storage options:
1. Confluent Storage, in which the Apache Iceberg tables are stored in Confluent Managed Storage.
2. Non-Confluent Storage (a.k.a, external object store, Bring Your Own Storage (BYOS)), Amazon S3.

So, the question you should be asking yourself is which one should I choose.  Well to help you, below I provide a pros and cons list:

Confluent Storage|Amazon S3
-|-
Not compatible with external data catalogs, like AWS Glue|You can use AWS Glue

Tableflow requires a cloud provider integration to be configured at the environment level of the topic(s) you’re enabling Tableflow on.  Multiple Tableflow-enabled topics can use the same S3 bucket and cloud provider integration. Tableflow supports only **S3 General Purpose or Directory bucket types** located in the same region as your Kafka cluster.

To access tables stored in Amazon S3, you must use an environment or resource that is authenticated with an AWS IAM role that has GetObject permissions for the objects stored in the S3 bucket where your table is stored.

**WARNING** Once you have enabled Tableflow on a topic with an Amazon S3 bucket as the storage, you can’t update that Tableflow-enabled topic to use another bucket or to use Confluent Managed Storage.

> _You should start with an empty bucket when you first enable Tableflow. Existing objects in the bucket may cause Tableflow to fail to start or may be lost entirely during initialization. Do not directly modify or delete objects from this bucket. Doing so may lead to table corruption._

Tableflow supports [Role-based Access Control (RBAC)](https://docs.confluent.io/cloud/current/security/access-control/rbac/overview.html#cloud-rbac) for managing access to Tableflow resources. There are no Tableflow-specific roles to configure, and access to Tableflow typically mirrors access to Apache Kafka® resources.  For more information on the specific roles, scope, and permitted management operations of Tableflow, go to this [link](https://docs.confluent.io/cloud/current/topics/tableflow/operate/tableflow-rbac.html#access-to-tableflow-resources).


