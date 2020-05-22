def label = "jenkins-slave-${UUID.randomUUID().toString()}"

// 参数定义

def dockerRegistryUrl = "192.168.195.2";
// 在第 2 阶段中自动会去赋值
def imageTag = "";
def appName = "";
def podName = "";
def image = "";
def groupId = "";

// 方法定义

/**
 * 创建 podName
 *
 * @param args imageTag, isActiveVersionOverride, activeVersionOverride, isPodNameOverride, podNameOverride, appName
 * @return podName
 */
def createPodName(Map args) {
    println "createPodName 方法的输入参数" + args.toString()
    def podName
    def podNameSuffix = "${args.imageTag}"
    if ("true" == "${args.isActiveVersionOverride}") {
        podNameSuffix = "${args.activeVersionOverride}"
    }
    if ("true" == "${args.isPodNameOverride}") {
        podName = "${args.podNameOverride}-${podNameSuffix}".replaceAll("\\.", "-").toLowerCase()
    } else {
        podName = "${args.appName}-${podNameSuffix}".replaceAll("\\.", "-").toLowerCase()
    }
    return podName
}

/**
 * 使用 Helm 部署应用
 *
 * @param args helmDelete, helmInstall, helmUpgrade,
 *             appName, podName, chartDir, namespace, dockerRegistryUrl, image, imageTag,
 *             isActiveVersionOverride, activeVersionOverride,
 *             serviceType
 * @return
 */
def helmDeploy(Map args) {
    println "helmDeploy 方法的输入参数" + args.toString()
    def activeVersion = "${args.imageTag}"
    def active = "test\\,version-${activeVersion}"
    if ("true" == "${args.isActiveVersionOverride}") {
        activeVersion = "${args.activeVersionOverride}"
        active = "test\\,version-${args.activeVersionOverride}"
    }
    def helmCommandArgs = "--set "
    helmCommandArgs = helmCommandArgs + "image.repository=${args.dockerRegistryUrl}/${args.image}"
    helmCommandArgs = helmCommandArgs + ",image.tag=${args.imageTag}"
    helmCommandArgs = helmCommandArgs + ",nameOverride=${args.appName}"
    helmCommandArgs = helmCommandArgs + ",fullnameOverride=${args.podName}"
    helmCommandArgs = helmCommandArgs + ",springCloud.active=\"${active}\""
    helmCommandArgs = helmCommandArgs + ",springCloud.tags=version=${activeVersion}"
    if ("${args.serviceType}" == null) {
        helmCommandArgs = helmCommandArgs + ",service.type=NodePort"
    } else if ("${args.serviceType}".contains(":")) {
        // 只有 NodePort 才有可能有 ":"
        def svc = "${args.serviceType}".split(":")
        helmCommandArgs = helmCommandArgs + ",service.type=${svc[0]},service.nodePort=${svc[1]}"
    } else {
        helmCommandArgs = helmCommandArgs + ",service.type=${args.serviceType}"
    }


    if ("true" == "${args.helmDelete}") {
        echo "[INFO] Helm 删除应用..."
        sh "helm delete ${args.podName} -n ${args.namespace}"
        echo "[INFO] Helm 删除应用成功."
    }
    if ("true" == "${args.helmInstall}") {
        echo "[INFO] Helm 部署应用..."
        sh """
            helm install ${args.podName} ./${args.chartDir} --namespace=${args.namespace} ${helmCommandArgs}
           """
        echo "[INFO] Helm 部署应用成功."
    }
    if ("true" == "${args.helmUpgrade}") {
        echo "[INFO] Helm 升级应用..."
        sh """
            helm upgrade ${args.podName} ./${args.chartDir} --namespace=${args.namespace} ${helmCommandArgs}
           """
        echo "[INFO] Helm 升级应用成功"
    }
}

podTemplate(label: label, containers: [
        containerTemplate(name: 'maven', image: 'maven:3.6.3-jdk-8', command: 'cat', ttyEnabled: true),
        containerTemplate(name: 'docker', image: 'docker', command: 'cat', ttyEnabled: true),
        containerTemplate(name: 'helm-kubectl', image: 'dtzar/helm-kubectl:3.1.2', command: 'cat', ttyEnabled: true)
], volumes: [
        nfsVolume(mountPath: '/root/.m2', readOnly: false, serverAddress: '192.168.200.19', serverPath: '/home/k8s-projects/k8s-nfs/m2'),
        nfsVolume(mountPath: '/usr/share/maven/ref', readOnly: false, serverAddress: '192.168.200.19', serverPath: '/home/k8s-projects/k8s-nfs/maven-ref'),
        hostPathVolume(mountPath: '/home/jenkins/.kube', hostPath: '/root/.kube'),
        hostPathVolume(mountPath: '/var/run/docker.sock', hostPath: '/var/run/docker.sock')
]) {
    node(label) {
        stage('代码检出') {
            echo "1. 代码检出阶段";
            sh """
               rm -fr ./*
               mkdir ${mavenProjects}
               mkdir ${chartDir}
               """
            echo "[INFO] 检出项目源码"
            checkout([$class: 'SubversionSCM', additionalCredentials: [], excludedCommitMessages: '', excludedRegions: '', excludedRevprop: '', excludedUsers: '', filterChangelog: false, ignoreDirPropChanges: false, includedRegions: '', locations: [[cancelProcessOnExternalsFail: true, credentialsId: "${jenkinsSVNCredentialsId}", depthOption: 'infinity', ignoreExternalsOption: true, local: "${mavenProjects}", remote: "${svnRemote}"]], quietOperation: true, workspaceUpdater: [$class: 'UpdateUpdater']])
            echo "[INFO] 检出 helm chart"
            checkout([$class: 'SubversionSCM', additionalCredentials: [], excludedCommitMessages: '', excludedRegions: '', excludedRevprop: '', excludedUsers: '', filterChangelog: false, ignoreDirPropChanges: false, includedRegions: '', locations: [[cancelProcessOnExternalsFail: true, credentialsId: "${jenkinsSVNCredentialsId}", depthOption: 'infinity', ignoreExternalsOption: true, local: "${chartDir}", remote: "${svnHelm}"]], quietOperation: true, workspaceUpdater: [$class: 'UpdateUpdater']])
            echo "[INFO] 检出项目源码成功！"
        }
        stage('单元测试') {
            try {
                container('maven') {
                    echo "2. 测试阶段";
                    echo "项目 SVN 地址: ${svnRemote}"

                    imageTag = sh(script: "cd ${mavenProjects}/${projectPath} && mvn -Dexec.executable='echo' -Dexec.args='\${project.version}' --non-recursive exec:exec -q", returnStdout: true).trim()
                    echo "[INFO] project.version = imageTag = ${imageTag}"

                    appName = sh(script: "cd ${mavenProjects}/${projectPath} && mvn -Dexec.executable='echo' -Dexec.args='\${project.artifactId}' --non-recursive exec:exec -q", returnStdout: true).trim()
                    echo "[INFO] project.artifactId = appName = ${appName}"

                    groupId = sh(script: "cd ${mavenProjects}/${projectPath} && mvn -Dexec.executable='echo' -Dexec.args='\${project.groupId}' --non-recursive exec:exec -q", returnStdout: true).trim()
                    echo "[INFO] project.groupId = groupId = ${groupId}"

                    podName = createPodName(
                            imageTag: "${imageTag}",
                            isActiveVersionOverride: "${isActiveVersionOverride}",
                            activeVersionOverride: "${activeVersionOverride}",
                            isPodNameOverride: "${isPodNameOverride}",
                            podNameOverride: "${podNameOverride}",
                            appName: "${appName}"
                    )
                    echo "[INFO] PodName = ${podName}"

                    image = "${namespace}/${appName}"
                    echo "[INFO] image = ${image}"

                    echo "[INFO] maven 编译模块目标: ${mvnBuildModules}"
                    echo "[INFO] Docker 构建目标: ${dockerRegistryUrl}/${image}"
                    echo "[INFO] Helm 模板地址: ${svnHelm}"
                    echo "[INFO] Helm 命名空间: ${namespace}"
                    echo "[INFO] Helm 应用名称: ${podName}"
                    echo "[INFO] Helm 删除应用：${helmDelete}"
                    echo "[INFO] Helm 部署应用：${helmInstall}"
                    echo "[INFO] Helm 升级应用：${helmUpgrade}"
                }
            } catch (exc) {
                println "获取maven信息失败 - ${currentBuild.fullDisplayName}"
                throw (exc)
            }
        }
        stage('代码编译打包') {
            try {
                container('maven') {
                    echo "3. 代码编译打包阶段"
                    sh """
                       cd ${mavenProjects}
                       mvn clean install -pl ${mvnBuildModules} -amd -Dmaven.test.skip=true
                       """
                }
            } catch (exc) {
                println "构建失败 - ${currentBuild.fullDisplayName}"
                throw (exc)
            }
        }
        stage('构建 Docker 镜像') {
            withCredentials([usernamePassword(credentialsId: 'DockerHub', passwordVariable: 'dockerHubPassword', usernameVariable: 'dockerHubUser')]) {
                container('docker') {
                    echo "4. 构建 Docker 镜像阶段"
                    def groupIdPath = groupId.replaceAll("\\.", "/")
                    sh """
                       cd ${mavenProjects}
                       mkdir cicd
                       cp Dockerfile cicd/
                       cd cicd
                       cp /root/.m2/repository/${groupIdPath}/${appName}/${imageTag}/*.jar ./ && pwd && ls
                       docker login ${dockerRegistryUrl} -u ${dockerHubUser} -p ${dockerHubPassword}
                       docker build -t ${dockerRegistryUrl}/${image}:${imageTag} .
                       docker push ${dockerRegistryUrl}/${image}:${imageTag}
                       """
                }
            }
        }
        stage('运行 Helm 阶段') {
            container('helm-kubectl') {
                echo "5. 运行 Helm 阶段"
                echo "[INFO] 开始运行 Helm 命令"
                helmDeploy(
                        helmDelete: "${helmDelete}",
                        helmInstall: "${helmInstall}",
                        helmUpgrade: "${helmUpgrade}",
                        appName: "${appName}",
                        podName: "${podName}",
                        chartDir: "${chartDir}",
                        namespace: "${namespace}",
                        dockerRegistryUrl: "${dockerRegistryUrl}",
                        image: "${image}",
                        imageTag: "${imageTag}",
                        isActiveVersionOverride: "${isActiveVersionOverride}",
                        activeVersionOverride: "${activeVersionOverride}",
                        serviceType: "${serviceType}"
                )
            }
        }
    }
}