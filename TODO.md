# Project Todo List

## Missing / Future Components

### Testing & Quality Assurance
- [ ] **Unit Tests**: Add comprehensive unit tests for `producer.py` and Spark jobs.
- [ ] **Integration Tests**: Create an automated integration test suite that spins up the stack and verifies end-to-end data flow.
- [ ] **Data Quality Checks**: Implement Great Expectations or similar for data validation in the pipeline.

### Infrastructure & Operations
- [ ] **Monitoring Stack**: Add Prometheus/Grafana for metric visualization (Kafka lag, Flink backpressure, etc.).
- [ ] **Alerting**: Configure alerts for pipeline failures or high latency.
- [ ] **Terraform**: Consider migrating shell scripts to Terraform for more robust infrastructure management.
- [ ] **Containerization**: Dockerize the entire stack for local development (docker-compose).

### Features
- [ ] **Schema Registry**: Integrate Confluent Schema Registry for better Avro support.
- [ ] **Machine Learning**: Add a training pipeline for trip duration or fare prediction.
- [ ] **Real-time Dashboard**: Add more complex real-time metrics (e.g., anomaly detection).

### Documentation
- [ ] **API Documentation**: If APIs are added, document them with Swagger/OpenAPI.
- [ ] **Disaster Recovery**: Create a specific guide for disaster recovery scenarios.
