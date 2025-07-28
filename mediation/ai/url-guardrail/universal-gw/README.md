# URL Guardrail Mediator for WSO2 API Manager Universal Gateway

The **URL Guardrail** is a custom Synapse mediator for **WSO2 API Manager Universal Gateway**, designed to perform **URL validity checks** on incoming or outgoing JSON payloads. This component acts as a *guardrail* to enforce content safety by validating embedded URLs for accessibility or DNS resolution.

---

## Features

- Validate payload content by extracting and checking URLs
- Perform either **DNS resolution** or **HTTP HEAD** validation
- Target specific fields in JSON payloads using **JSONPath**
- Configure custom **timeout** for validation checks
- Trigger fault sequences on rule violations
- Include optional **assessment messages** in error responses for better observability

---

## Prerequisites

- Java 11 (JDK)
- Maven 3.6.x or later
- WSO2 API Manager or Synapse-compatible runtime

---

## Building the Project

To compile and package the mediator:

```bash
mvn clean install
```

> ℹ️ This will generate a `.zip` file in the `target/` directory containing the mediator JAR, policy-definition.json, and artifact.j2.

---

## How to Use

Follow these steps to integrate the URL Guardrail policy into your WSO2 API Manager instance:

1. **Unzip the Build Artifact**

```bash
unzip target/org.wso2.apim.policies.mediation.ai.url-guardrail-<version>-distribution.zip -d url-guardrail
```

2. **Copy the Mediator JAR**

```bash
cp url-guardrail/org.wso2.apim.policies.mediation.ai.url-guardrail-<version>.jar $APIM_HOME/repository/components/lib/
```

3. **Register the Policy in Publisher**

- Use the `policy-definition.json` and `artifact.j2` files to define the policy in the Publisher Portal.
- Place them appropriately in your custom policy deployment directory or register via the REST API.

4. **Apply and Deploy the Policy**

- Go to **API Publisher**
- Select your API
- Navigate to **Runtime > Request/Response Flow**
- Click **Add Policy** and choose **URL Guardrail**
- Configure the policy parameters (name, JSONPath, timeout, etc.)
- **Save and Deploy** the API

---

## Example Policy Configuration

1. Create an AI API using Mistral AI.
2. Add the URL Guardrail policy to the API with the following configuration:

| Field                       | Example                  |
|-----------------------------|--------------------------|
| `Guardrail Name`            | `URL Safety Guard`       |
| `JSON Path`                 | `$.messages[-1].content` |
| `Connection Timeout`        | `3000`                   |
| `Perform DNS Lookup`        | `false`                  |
| `Show Guardrail Assessment` | `false`                  |

3. Save and re-deploy the API.
4. Invoke the API's `chat/completion` endpoint with a prompt that violates the URL validity rule.

```json
{
  "model": "mistral-small-latest",
  "messages": [
    {
      "role": "user",
      "content": "Please summerize content from http://test.fake"
    }
  ]
}
```

The following guardrail error response will be returned with http status code `446`:

```json
{
  "code": "900514",
  "type": "URL_GUARDRAIL",
  "message": {
    "interveningGuardrail": "URL Safety Guard",
    "action": "GUARDRAIL_INTERVENED",
    "actionReason": "Violation of url validity detected.",
    "direction": "REQUEST"
  }
}
```

---

## Limitations

The **URL Guardrail** uses the following regular expression to extract URLs from the inspected content:

```regex
https?://[^\\s,"'{}\[\]\\`*]+
```

This pattern is designed to match common URL formats in textual content. However, it may **overmatch** or extract **unintended portions** as URLs in certain edge cases.

> 🔒 If such unintended content is matched as a URL and fails the validation (DNS/HTTP), the guardrail will **intervene** and block the mediation flow.

---