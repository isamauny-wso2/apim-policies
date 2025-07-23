# Regex PII Masking Policy for WSO2 API Manager Universal Gateway

The **Regex PII Masking Policy** is a custom Synapse mediator designed to safeguard Personally Identifiable Information (PII) in AI API traffic by leveraging user-defined regular expressions. It provides flexible, rule-based mechanisms to detect and obscure sensitive data in both request and response flows.

This policy enables organizations to apply consistent and automated masking or redaction of PII, thereby supporting privacy, compliance, and anonymization use cases.

---

## Features

- Detect and process PII using **customizable regex patterns**
- Operate in **Masking** and **Redacting** modes
- Apply transformations to **request**, **response**, or **both** flows
- Ensure **data privacy** without disrupting backend systems
- Restore original data on response (only in Masking mode)

---

## Modes of Operation

### 1. **Masking Mode**

- PII detected in the **request** is **anonymized** before it reaches the backend (e.g., `Alex` → `Person_0001`)
- In the **response**, previously anonymized entities are **restored** to their original form, ensuring data fidelity for AI API consumers
- Best suited for use cases where downstream systems require de-identified input but clients expect original data in responses

### 2. **Redacting Mode**

- PII detected in **request** or **response** flows is **permanently redacted** (e.g., `Alex` → `*****`)
- Original data is **not restored**
- Applicable in both request and response flows
- Ideal for scenarios where sensitive data must be strictly removed before reaching any service or client

---

## Prerequisites

- Java 11 (JDK)
- Maven 3.6.x or later
- WSO2 API Manager or Synapse-compatible runtime

---

## Building the Project

To compile and package the policy:

```bash
mvn clean install
```

> ℹ️ This will generate a `.zip` file in the `target/` directory containing the mediator JAR, policy-definition.json, and artifact.j2.

---

## How to Use

Follow these steps to integrate the Regex PII Masking policy into your WSO2 API Manager instance:

1. **Unzip the Build Artifact**

   ```bash
   unzip target/org.wso2.apim.policies.mediation.ai.pii-masking-regex-<version>-distribution.zip -d regex-pii-guardrail
   ```

2. **Copy the Mediator JAR**

   ```bash
   cp regex-pii-guardrail/org.wso2.apim.policies.mediation.ai.pii-masking-regex-<version>.jar $APIM_HOME/repository/components/dropins/
   ```

3. **Register the Policy in Publisher**

   Use the provided `policy-definition.json` and `artifact.j2` files to define the policy in the Publisher Portal.

4. **Apply and Deploy the Policy**

    - Navigate to your API in **API Publisher**
    - Go to **Runtime > Request/Response Flow**
    - Add the **Regex PII Masking Policy**
    - Configure the regex patterns, masking mode, and applicable message fields
    - **Save and Deploy** the API

---

## Example Policy Configuration

### Mode: Masking

This example demonstrates how the policy can be used to anonymize PII in the request flow and restore it in the response.

1. Create an AI API with Mistral AI.
2. Add the `PII Masking with Regex` policy in the request flow with the following configuration:

| Field                      | Example                   |
|----------------------------|---------------------------|
| `Guardrail Name`           | `Mask Email PII`          |
| `JSON Path`                | `$.messages[-1].content`  |

`PII Entities`:
```json
[
  {
    "piiEntity": "EMAIL",
    "piiRegex": "([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+\\.[a-zA-Z0-9_-]+)"
  }
]
```

3. Add another `PII Masking with Regex` policy in the response flow with the following configuration:

| Field            | Example                        |
|------------------|--------------------------------|
| `Guardrail Name` | `Mask Email PII`               |
| `JSON Path`      | `$.choices[0].message.content` |
| `Redact PII`     | `false`                        |

`PII Entities`:
```json
[
  {
    "piiEntity": "EMAIL",
    "piiRegex": "([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+\\.[a-zA-Z0-9_-]+)"
  }
]
```

4. Save and re-deploy the API.
5. Invoke the API's `chat/completion` endpoint with the following payload:

```json
{
  "model": "mistral-small-latest",
  "messages": [
    {
      "role": "user",
      "content": "Summarize the following email:\n\nFrom: jane.doe@confidential-client.com\nTo: project-team@yourcompany.com\nSubject: Q3 Budget & Deliverables\n\nHi team,\n\nPlease ensure that all documents related to Q3 targets are reviewed by John Smith (john.smith@confidential-client.com) and forwarded to our legal team. Also loop in our finance contact, Emily Rose (emily.rose@confidential-client.com), for final budget approvals.\n\nRegards,\nJane"
    }
  ]
}
```

> ℹ️ Note: The policy attached in the request flow identifies and anonymizes PIIs in the request message and store the mapping in the synapse message context. The policy attached in the response flow retrieves the mapping from the synapse message context and restores the original PII entities in the response message.

### Mode: Redacting

Redacting mode can be applied to both request and response flows to permanently remove PII from messages. This example demonstrates how the policy can be used to redact PII in the request flow.

1. Create an AI API with Mistral AI.
2. Add the `PII Masking with Regex` policy in the request flow with the following configuration:

| Field            | Example                  |
|------------------|--------------------------|
| `Guardrail Name` | `Mask Email PII`         |
| `JSON Path`      | `$.messages[-1].content` |
| `Redact PII`     | `true`                   |

3. Save and re-deploy the API.
4. Invoke the API's `chat/completion` endpoint with the following payload:

```json
{
  "model": "mistral-small-latest",
  "messages": [
    {
      "role": "user",
      "content": "Summarize the following email:\n\nFrom: jane.doe@confidential-client.com\nTo: project-team@yourcompany.com\nSubject: Q3 Budget & Deliverables\n\nHi team,\n\nPlease ensure that all documents related to Q3 targets are reviewed by John Smith (john.smith@confidential-client.com) and forwarded to our legal team. Also loop in our finance contact, Emily Rose (emily.rose@confidential-client.com), for final budget approvals.\n\nRegards,\nJane"
    }
  ]
}
```
