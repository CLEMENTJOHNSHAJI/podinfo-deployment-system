# Architecture Overview

## System Architecture

```mermaid
graph TB
    subgraph "GitHub Actions CI/CD"
        A[Code Push] --> B[Build & Sign]
        B --> C[Generate SBOM]
        C --> D[Security Scan]
        D --> E[Deploy to Dev]
        E --> F[Smoke Tests]
        F --> G[Promote to Prod]
    end
    
    subgraph "AWS Infrastructure"
        subgraph "Global Resources"
            H[ECR Repositories]
            I[IAM OIDC Provider]
            J[KMS Key]
            K[SNS Topic]
            L[CloudWatch Dashboard]
        end
        
        subgraph "Lambda Target"
            M[API Gateway]
            N[Lambda Function]
            O[CodeDeploy App]
        end
        
        subgraph "EC2 Target"
            P[Application Load Balancer]
            Q[Auto Scaling Group]
            R[EC2 Instances]
            S[CodeDeploy App]
        end
        
        subgraph "Security & Monitoring"
            T[Secrets Manager]
            U[CloudWatch Logs]
            V[CloudWatch Alarms]
        end
    end
    
    A --> H
    E --> M
    E --> P
    G --> M
    G --> P
    H --> N
    H --> R
    T --> N
    T --> R
    U --> L
    V --> K
```

## Deployment Flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub Actions
    participant ECR as ECR
    participant Lambda as AWS Lambda
    participant EC2 as AWS EC2
    participant CW as CloudWatch
    
    Dev->>GH: Push to main branch
    GH->>ECR: Build & push images
    GH->>ECR: Sign images
    GH->>ECR: Generate SBOM
    GH->>Lambda: Deploy to Lambda
    GH->>EC2: Deploy to EC2
    GH->>CW: Run smoke tests
    GH->>CW: Update monitoring
    CW-->>Dev: Deployment complete
```

## Security Architecture

```mermaid
graph LR
    subgraph "Supply Chain Security"
        A[Source Code] --> B[Build Process]
        B --> C[Image Signing]
        C --> D[SBOM Generation]
        D --> E[Vulnerability Scan]
        E --> F[Policy Gates]
    end
    
    subgraph "Runtime Security"
        G[Secrets Manager] --> H[Encrypted Secrets]
        I[VPC] --> J[Network Isolation]
        K[IAM] --> L[Least Privilege]
        M[KMS] --> N[Encryption at Rest]
    end
    
    F --> G
    F --> I
    F --> K
    F --> M
```

## Monitoring Architecture

```mermaid
graph TB
    subgraph "Application Layer"
        A[Podinfo App - Lambda]
        B[Podinfo App - EC2]
    end
    
    subgraph "Infrastructure Layer"
        C[API Gateway]
        D[Application Load Balancer]
        E[Auto Scaling Group]
    end
    
    subgraph "Monitoring Layer"
        F[CloudWatch Logs]
        G[CloudWatch Metrics]
        H[CloudWatch Alarms]
        I[CloudWatch Dashboard]
    end
    
    A --> F
    B --> F
    C --> G
    D --> G
    E --> G
    F --> I
    G --> I
    H --> I
```

## Key Components

### CI/CD Pipeline
- **Build**: Container image building and signing
- **Sign**: Cosign keyless signing with GitHub OIDC
- **SBOM**: Software Bill of Materials generation
- **Scan**: Trivy vulnerability scanning
- **Deploy**: Dual target deployment (Lambda + EC2)
- **Test**: Automated smoke tests and validation

### Infrastructure
- **Global**: ECR, IAM, KMS, SNS, CloudWatch
- **Lambda**: API Gateway, Lambda function, CodeDeploy
- **EC2**: VPC, ALB, Auto Scaling Group, CodeDeploy
- **Security**: Secrets Manager, VPC, Security Groups

### Monitoring
- **Logs**: Centralized logging for all components
- **Metrics**: Performance and health metrics
- **Alarms**: Automated alerting for failures
- **Dashboard**: Real-time system overview

### Security
- **Supply Chain**: Image signing, SBOM, vulnerability scanning
- **Runtime**: Secrets management, network isolation, encryption
- **Access**: IAM roles with least privilege
- **Compliance**: Audit trails and policy enforcement
