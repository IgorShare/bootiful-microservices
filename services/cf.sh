#!/bin/bash
set -e

#
# the big CloudFoundry installer
#


CLOUD_DOMAIN=${DOMAIN:-run.pivotal.io}
CLOUD_TARGET=api.${DOMAIN}
BUS_SERVICE=bus-rabbitmq

function login(){
    cf api | grep ${CLOUD_TARGET} || cf api ${CLOUD_TARGET} --skip-ssl-validation
    cf a | grep OK || cf login
}

function app_domain(){
    D=`cf apps | grep $1 | tr -s ' ' | cut -d' ' -f 6 | cut -d, -f1`
    echo $D
}

### common
function deploy_cli_app(){
    cf cs cloudamqp tiger $BUS_SERVICE

    APP_NAME=$1
    cd $APP_NAME
    mkdir -p target
    spring jar target/$APP_NAME.jar script.groovy
    cf push $APP_NAME --no-start
    APPLICATION_DOMAIN=`app_domain $APP_NAME`
    echo determined that application_domain for $APP_NAME is $APPLICATION_DOMAIN.
    cf env $APP_NAME | grep APPLICATION_DOMAIN || cf set-env $APP_NAME APPLICATION_DOMAIN $APPLICATION_DOMAIN
    cf restart $APP_NAME
    cd ..

}
function deploy_app(){
    # common to all nodes
    cf cs cloudamqp tiger $BUS_SERVICE

    APP_NAME=$1
    cd $APP_NAME
    cf push $APP_NAME  --no-start
    APPLICATION_DOMAIN=`app_domain $APP_NAME`
    echo determined that application_domain for $APP_NAME is $APPLICATION_DOMAIN.
    cf env $APP_NAME | grep APPLICATION_DOMAIN || cf set-env $APP_NAME APPLICATION_DOMAIN $APPLICATION_DOMAIN
    cf restart $APP_NAME
    cd ..
}

function deploy_service(){
    N=$1
    D=`app_domain $N`
    JSON='{"uri":"http://'$D'"}'
    echo cf cups $N  -p $JSON
    cf cups $N -p $JSON
}

### specific services
function deploy_config(){
    NAME=config
    deploy_cli_app $NAME
    deploy_service $NAME
}

function deploy_eureka(){
    NAME=eureka
    deploy_cli_app $NAME
    deploy_service $NAME
}

function deploy_dashboard(){
    deploy_cli_app dashboard
}

function deploy_contacts(){
    cf cs elephantsql turtle contacts-postgresql
    deploy_app contacts
}


function deploy_bookmarks(){
    cf cs elephantsql turtle bookmarks-postgresql
    deploy_app bookmarks
}


#
#function deploy_eureka() {
#    NAME=eureka-service
#    deploy_app $NAME
#    deploy_service $NAME
#}
#
#function deploy_doge(){
#    cf cs mongolab sandbox doge-mongo
#    deploy_app doge-service
#}
#
#function deploy_account(){
#    cf cs elephantsql turtle doge-postgresql
#    deploy_app account-service
#}
#
#function deploy_hystrix(){
#    deploy_app hystrix-service
#}
#
#function deploy_webapp(){
#    deploy_app webapp
#}

function reset(){

    echo "reset.."
# apps
#    cf d -f config
#    cf d -f eureka
#    cf d -f dashboard
#    cf d -f contacts

# services
# cf ds -f $BUS_SERVICE
# cf ds -f config
# cf ds -f eureka
# cf ds -f dashboard


#    cf d -f eureka-service
#    cf d -f doge-service
#    cf d -f account-service
#    cf d -f hystrix-service
#    cf d -f webapp
#
#    cf ds -f config-service
#    cf ds -f eureka-service
#
    cf delete-orphaned-routes -f

}


### INSTALLATION STEPS
### feel free to comment out all the steps that you don't need
### and selectively uncomment them if the script in total encounters
### IO errors and such.

mvn -DskipTests=true clean install

# login
# reset
# deploy_config
# deploy_eureka
# deploy_dashboard

deploy_contacts
deploy_bookmarks