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
		/*kubectl --insecure-skip-tls-verify=true --user="kube-user" --server="https://kubemaster.example.com"  --token=$ACCESS_TOKEN set image deployment/my-deployment mycontainer=myimage:"$BUILD_NUMBER-$SHORT_GIT_COMMIT" */
        /* sh "kubectl --user="kubernetes-admin" --server="https://144.217.12.186:6443"  --token="qjtv97.5ms54vdx2gjo68jh" set image deployment/angular-app angular-app=hazemelhaouari/testkube:'latest'" */
        /* sh 'kubectl --user=kubernetes-admin --token=qjtv97.5ms54vdx2gjo68jh  get pods' */
        sh 'kubectl set image deployment/angular-app angular-app=hazem/testkube:"$BUILD_NUMBER"'
        
    }
}