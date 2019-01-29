![Tutorial CI/CD Docker Jenkins Kubernetes ](/ressources/design.png)

# Tutorial-Kubernetes-jenkins-docker-Ubuntu16.04

This is a tutorial to automatise deployement of applications on VPS ubuntu 16.04 using Jenkins, Docker and Kubernetes.

## Kubernetes

This is how to configure kubernetes step by step

##### System Preparation

`sudo apt-get -y install apt-transport-https ca-certificates software-properties-common curl`

`sudo apt-get update && apt-get install -y apt-transport-https`

#### Install Docker

`sudo apt install docker.io`

##### start and enable docker

`sudo systemctl start docker`
`sudo systemctl enable docker`

##### Download and incorporate the Key

`sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add`

#### install kubernetes apt repo

`apt-get update && apt-get install -y apt-transport-https && curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -`

`echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list`

##### update packages

`apt-get update`

##### instal kubelet kubeadm kubernetes-cni

`apt-get update && apt-get install -y kubelet kubeadm kubernetes-cni`

#### initilaize kubeadm

`kubeadm init`

If you have NumCpu error run this command: `kubeadm init --ignore-preflight-errors=NumCP`

#### Kubectl configuration on local machine

install kubectl on your local machine https://kubernetes.io/docs/tasks/tools/install-kubectl/

Now copy the config from the master:
`scp root@your-master-ip-here:/etc/kubernetes/admin.conf ~/.kube/config`

##### Tainting the master

Now we need to allow the master to be scheduled as a node so that pods can run on it (Nodes are expensive as you know)
From local machine run

`kubectl taint nodes --all node-role.kubernetes.io/master-`

#### Installing the network provider

- on the master:

`sudo sysctl net.bridge.bridge-nf-call-iptables=1`

Or you can do this:
`sudo nano /etc/sysctl.conf` And than copy this at the end: `net.bridge.bridge-nf-call-iptables=1`

- From local machine run:
`kubectl apply -n kube-system -f "https://cloud.weave.works/k8s/v1.6/net"`

#### Install kubernetes Dashboard
From local run:
`kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml`

##### Run and open kubernetes Dashboard

From local run:
`kubectl proxy`

Than you can open this url: http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/

Now you need to have an admin user to acced. This is what we will do next

#### Create Admin user

Create two files on local machine configurations adminuser.yaml and clusterRoleBinding.yaml to create user and give him credentials to access.

Content of adminuser.yaml :

``` 
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kube-system
```

clusterRoleBinding.yaml content:

```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kube-system
```

Now to create the admin-user run from local and don't forget to change FilePath with your file path:
`kubectl create -f FilePath/adminuser.yaml`

Add now a cluster role binding to make sure he has all the admin privileges and don't forget to change FilePath with your file path:
`kubectl create -f FilePath/clusterRoleBinding.yaml`

##### get access token to connect to dashbord

`kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')`

Now copy the token to get access to the url http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/

## Install Jenkins

install java 8

`apt install openjdk-8-jre-headless`

Add packages of jenkins and install it
`wget -q -O - https://pkg.jenkins.io/debian/jenkins-ci.org.key | sudo apt-key add -`

`echo deb https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list`

`sudo apt-get update`

`sudo apt-get install jenkins`

##### Start Jenkins

`sudo systemctl start jenkins`

##### Check Jenkins status

`sudo systemctl status jenkins`

Now open the url: server-ip:8080

#### Configure jenkins

copy token to login
`sudo cat /var/lib/jenkins/secrets/initialAdminPassword`

than choose instal suggested plugins

Create first admin user

Click start using jenkins

#### Configuring docker for jenkins

`sudo groupadd docker`
`sudo usermod -aG docker jenkins`
`sudo chmod 777 /var/run/docker.sock`

#### Configure jenkins to access to Kubernetes

`mkdir /var/lib/jenkins/.kube/`
`sudo cp -i /etc/kubernetes/admin.conf /var/lib/jenkins/.kube/config`
`sudo chmod 777 /var/lib/jenkins/.kube/config`

Now on jenkins dashboard click "Manage Jenkins" than click "Manage Plugins" On availabe search "Blue Ocean" and install it to facilitate pipelines
Now install the pludin for docker "CloudBees Docker Build and Publish"

## Configure application to deploy
Now on your own application do this steps. In our case, it is an angular application and all the file are in this Repo.
First we should add file with name 'Dockerfile' to the application wich will be used by docker to build the image
Example of content for Angular application:
```
FROM node:latest as node
WORKDIR /app
COPY . .
RUN npm install
RUN npm run build --prod

FROM nginx:latest
COPY --from=node /app/dist/testkube /usr/share/nginx/html
```

Now we add the deploy.yaml for kubernetes config
Example of Content for Angular application:
```
apiVersion: v1
kind: Service
metadata:
  name: angular-app
  labels:
    run: angular-app
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  - port: 443
    protocol: TCP
    name: https
  selector:
    run: angular-app

apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: angular-app
spec:
  replicas: 1
  template:
    metadata:
      labels:
        run: angular-app
    spec:
      containers:
      - name: angular-app
        image: hazem/testkube
        ports:
        - containerPort: 80
        - containerPort: 443   
        imagePullPolicy:Never
```

Ps: "imagePullPolicy:Never" at the end indicates that the cluster will never pull image from docker. We put it because we will push image from local build. But if you use docker hub, don't put it or put "imagePullPolicy:Always"

To deploy this application on kubernetes cluster, we run and don't forgot to change "applicationRoot" by your application path:
`kubectl apply -f applicationRoot/deploy.yaml`

If you run `kubectl get pods` you will see that the application deployed but doesn't work because actually there is no image in the master machine.

Now we will create the pipeline to fix all of this and automatize deployment:

#### Configure pipeline

First we should add the file "Jenkinsfile" to the application
Example of content to run image from local build on kubernetes:
```
node {
    def app

    stage('Clone repository') {
        /* Let's make sure we have the repository cloned to our workspace */

        checkout scm
    }

    stage('Build image') {
        /* This builds the actual image; synonymous to
         * docker build on the command line */

        app = docker.build("hazem/testkube:${BUILD_NUMBER}")
    }

    stage('Test image') {
        /* Ideally, we would run a test framework against our image.
         * For this example, we're using a Volkswagen-type approach ;-) */

        app.inside {
            sh 'echo "Tests passed"'
        }
    }
	
	stage('Deploy') {
        sh 'kubectl set image deployment/angular-app angular-app=hazem/testkube:"$BUILD_NUMBER"'   
    }
}
```

you can add this code before stage deploy if you use docker hub
```
	stage('Push image') {
         *Finally, we'll push the image with two tags:
         *First, the incremental build number from Jenkins
         * Second, the 'latest' tag.
         * Pushing multiple tags is cheap, as all the layers are reused. */
        docker.withRegistry('https://registry.hub.docker.com', 'docker-hub-credentials') {
            app.push("${env.BUILD_NUMBER}")
            app.push("$BUILD_NUMBER")
        }
    } 
 ```
 
 Now commit changes of your application to github than crate a pipeline from jenkins dashboard.
 To be easy use blue ocean from this url your-server-ip:8080/blue
After the jod complete, to get your app port run : `kubectl get services` and then copy the NodePort of Http.
Now Open your-server-ip:your-app-nodeport
You will see your app.


# References
This work is done thanks to this:

- https://medium.com/@smijar/installing-kubernetes-all-in-one-on-a-low-resource-vps-1c89dd5f0096
- https://hostadvice.com/how-to/how-to-set-up-kubernetes-in-ubuntu/
- https://www.digitalocean.com/community/tutorials/how-to-install-jenkins-on-ubuntu-16-04
- https://jenkins.io/doc/book/pipeline/
- https://kubernetes.io/docs/tasks/run-application/run-stateless-application-deployment/
- https://github.com/kubernetes/dashboard
- https://github.com/HoussemDellai/angular-app-kubernetes

      

  `
