# KUSTOMIZE <img src="https://github.com/manisankar-divi/k8s-repo/blob/production/k.png" width="33"/>

This repository demonstrates how to use [kustomize](https://kubectl.docs.kubernetes.io/guides) for managing Kubernetes manifests in a modular and reusable way. It includes a simple example with a base configuration and environment-specific overlays (e.g., staging, prod).

## Installation
To find the kustomize version embedded in recent versions of [kubectl](https://kubernetes.io/docs/tasks/tools/), run kubectl version:

```bash
kubectl version --client
```
output looks like below:
```bash
Client Version: v1.32.3
Kustomize Version: v5.5.0    ---> Already Installed
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

The base directory includes the Production Running Yaml manifests shared across overlays/staging Environment. For example:

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

  - **patch.yaml** in this we can write configuration for staging environment like deployment/statefulset, service, configmap, namespace, pv, pvc, etc..  in one single patch file 

- **kustomization.yaml**
  - **kustomization.yaml** is the staging configuration file used by Kustomize, a Kubernetes-native tool that lets you customize Kubernetes manifests without modifying base YAML files.

## Demo Nginx service kustomization

_A guide on how to implement nginx service._

nginx (serviceName)
├── base
│   ├── nginx-deployment.yaml
│   ├── nginx-service.yaml
│   ├── nginx-configmap.yaml
│   ├── nginx-namespace.yaml
│   └── kustomization.yaml
└── overlays/
    └── staging
        ├── kustomization.yaml
        └── nginx-patch.yaml


### Create the step by step process for base.
#### Step:1
```yaml
mkdir nginx
cd nginx
mkdir base
mkdir -p overlays/staging
cd base
# base is production files
```
#### Step:2
`vim nginx-namespace.yaml`
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: nginx  #Replace your required Name
```
#### Step:3
`vim nginx-configmap.yaml`
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config  #Replace your required configmap-name
  namespace: nginx  #Replace your required Name
data:  #Replace your required configmap-data
  index.html: |
    <html>
      <body>
        <h1>Welcome to nginx! production</h1>
      </body>
    </html>
```

#### Step:4
`vim nginx-deployment.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx    #Replace your required serviceName
  namespace: nginx    #Replace your required Name
spec:
  affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: servers.com/label  #Replace your required servers name
                    operator: In
                    values:
                      - "Enter here your server name"
  replicas: 1    #Replace your required count
  selector:
    matchLabels:
      app: nginx  #Replace your required serviceName
  template:
    metadata:
      labels:
        app: nginx    #Replace your required serviceName
    spec:
      containers:
      - name: nginx      #Replace your required container name
        image: nginx:latest    #Replace your required Image name
        ports:
            - containerPort: 80    #Replace your required container port number
        volumeMounts:
        - name: html    #Replace your required Volume  name
          mountPath: /usr/share/nginx/html    #Replace your required file path
      volumes:  
      - name: html    #Replace your required volume name
        configMap:
          name: nginx-config    #Replace your required Configmap name
```

#### Step:5
`vim nginx-service.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx    #Replace your required service name
  namespace: nginx  #Replace your required name
spec:
  selector:
    app: nginx  #Replace your required serviceName
  type: NodePort  #Replace your required type (ClusterIP,NodePort,LoadBalancer)
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30000  #Replace your required port number.
```
#### Step:6
`vim kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:  #Replace your required serviceName
  - nginx-namespace.yaml
  - nginx-configmap.yaml
  - nginx-deployment.yaml
  - nginx-service.yaml
  - nginx-*.yaml  (Add list of files)
```

### Create the step by step process for overlays/staging.
#### Step:1

`vim kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base # Reference the base directory
patches:
  - path: nginx-patch.yaml
```
#### Step:2

`vim nginx-patch.yaml`
```yaml
# If you not mention it will pick from base directory.
# nignx-deployment-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx    #Replace your required serviceName staging
  namespace: nginx    #Replace your required Name
spec:
  replicas: 2    #Replace your required count staging
  template:
    spec:
      affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                  - matchExpressions:
                      - key: servers.com/label  #Replace your required servers name staging
                        operator: In
                        values:
                          - "Enter here your server name" # Replace your required name staging
      containers:
      - name: nginx      #Replace your required container name staging
        image: nginx:1.27.4-alpine3.21    #Replace your required Image name  staging
        ports:
            - containerPort: 80    #Replace your required container port number staging
        volumeMounts:
        - name: html    #Replace your required Volume  name staging
          mountPath: /usr/share/nginx/html    #Replace your required file path staging
      volumes:  
      - name: html    #Replace your required volume name staging
        configMap:
          name: nginx-config-staging    #Replace your required Configmap name staging
---
# If you not mention it will pick from base directory.
# nginx-service-patch
apiVersion: v1
kind: Service
metadata:
  name: nginx    #Replace your required service name staging
  namespace: nginx  #Replace your required name 
spec:
  selector:
    app: nginx  #Replace your required serviceName staging
  type: NodePort  #Replace your required type (ClusterIP,NodePort,LoadBalancer) staging
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30001  #Replace your required port number. staging
---
# If you not mention it will pick from base directory.
# nginx-confimap-patch.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config-staging  #Replace your required configmap-name for staging
  namespace: nginx  #Replace your required Name
data:  #Replace your required configmap-data staging
  index.html: |
    <html>
      <body>
        <h1>Welcome to nginx! staging</h1>
      </body>
    </html>
```
`Note: Namespace in staging will taken from base directory nginx-namespace.yaml, we can add diff namespace if we need`

## commands to build kustomize
Check base kustomize yaml files. build keyword is like dry-run.
```bash
cd nginx
kustomize build base
```
Verify build successfully gives output.

Check overlays/staging yaml files.
```bash
cd nginx
kustomize build overlays/staging
```
Verify build successfully gives output.
## commands to apply kustomize yaml files.
```bash
cd nginx
kubectl apply -k base
```
Verify successfully created or not.


```bash
cd nginx
kubectl apply -k overlays/staging
```
Verify successfully created or not.
## Official Documentation
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [kustomize](https://kubectl.docs.kubernetes.io/guides)
- [kubernetes](https://kubernetes.io/docs/home/)
