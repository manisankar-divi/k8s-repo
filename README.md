# KUSTOMIZE <img src="https://github.com/manisankar-divi/k8s-repo/blob/production/k.png" width="33"/>

This repository demonstrates how to use Kustomize for managing Kubernetes manifests in a modular and reusable way. It includes a simple example with a base configuration and environment-specific overlays (e.g., staging, prod).

## Installation
To find the kustomize version embedded in recent versions of kubectl, run kubectl version:

```bash
kubectl version --client
```
output looks like below:
```bash
Client Version: v1.32.3
Kustomize Version: v5.5.0
```

Otherwise Install Below package in your linux machine.
```bash
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
```

Install Below package in your Mac machine.
```bash
brew install kustomize
```

Install Below package in your windows machine.
```bash
choco install kustomize
```

To check kustomize version 

```bash
kustomize version
  or
kubectl version --client
```
## Directory Structure

The repository is organized as follows:
![image description](https://github.com/manisankar-divi/k8s-repo/blob/production/k-st.png)

serviceName
├── base (Production files)
│ ├── serviceName-deployment.yaml / statefulset.yaml
│ ├── serviceName-service.yaml
│ ├── serviceName-configmap.yaml
│ ├── serviceName-namespace.yaml
│ ├── serviceName-*.yaml
│ └── kustomization.yaml
├── overlays
│ └── staging
│    ├── serviceName-patch.yaml
│    └── kustomization.yaml
└── README.md

## base (Production yaml files)

The base directory includes the Production Running Yaml manifests shared across Overlays/staging Environment. For example:

- **serviceName-deployment.yaml / statefulset.yaml:**

  - **deployment.yaml** is used to manage stateless applications in Kubernetes, where all pods are identical and can be replaced anytime, such as web servers or APIs. On the other hand, **statefulset.yaml** is used for stateful applications that need stable network identities and persistent storage, like databases (e.g., PostgreSQL or Kafka). While Deployments focus on scalability and high availability, StatefulSets ensure data consistency and ordered pod management.

- **serviceName-service.yaml:**

  - **service.yaml** is a Kubernetes configuration file used to define a Service, which exposes a set of pods and enables network access to them. It acts as a stable endpoint (IP/hostname) for communication, even if the underlying pods change.

- **serviceName-configmap.yaml**

  - **configmap.yaml** is a Kubernetes configuration file used to define a ConfigMap, which stores non-sensitive configuration data as key-value pairs. It helps you decouple configuration from application code, allowing changes without rebuilding your container image.
 
- **serviceName-namespace.yaml**

  - **namespace.yaml** In Kubernetes, a namespace is a mechanism for isolating groups of resources within a single cluster. It provides a scope for names, allowing resources to have unique names within a namespace but not necessarily across namespaces.

- **kustomization.yaml**
  - **kustomization.yaml** is the main configuration file used by Kustomize, a Kubernetes-native tool that lets you customize Kubernetes manifests without modifying the original YAML files.

The base/kustomization.yaml file references these resources.

## overlays/staging

The overlays/staging directory includes the staging Environment Yaml manifests:

- **serviceName-patch.yaml:**

  - **deployment.yaml** is used to manage stateless applications in Kubernetes, where all pods are identical and can be replaced anytime, such as web servers or APIs. On the other hand, **statefulset.yaml** is used for stateful applications that need stable network identities and persistent storage, like databases (e.g., PostgreSQL or Kafka). While Deployments focus on scalability and high availability, StatefulSets ensure data consistency and ordered pod management.

- **kustomization.yaml**
  - **kustomization.yaml** is the staging configuration file used by Kustomize, a Kubernetes-native tool that lets you customize Kubernetes manifests without modifying base YAML files.

### Prerequisites

_A guide on how to install the tools needed for running the project._

Explain the process step by step.

```bash
Install something
```

## Usage

Explain how to test the project and give some example.

```bash
Example
```

## Deploy

Describe the tools needed to deploy a new project.

## Technologies

_Name the technologies used in the project._

- [Spring](https://spring.io/) - Framework Used.
- [React](https://reactjs.org/) - UI Library.
- [Hibernate](https://hibernate.org/) - ORM.

## Contributing

Describe the steps to follow if someone wants to contribute to your project.

## Documentation

Specify [where](https://es.wikipedia.org/wiki/Wikipedia:Portada) people can find more documentation about your project.

## Acknowledgments

_Mention all those who helped you build the project, inspired you etc._

- [Linus Torvalds](https://github.com/torvalds)
- [Dan Abramov](https://github.com/gaearon)

## License

Describe the project [license](https://choosealicense.com/) agreements.
