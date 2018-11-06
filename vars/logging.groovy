#!/usr/bin/env groovy

def debug(String message) {
    wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'XTerm']) {
        echo "\033[34mDEBUG\033[0m\t${message}"
    }
}

def info(String message) {
    wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'XTerm']) {
        echo "\033[32mINFO\033[0m\t${message}"
    }
}

def warn(String message) {
    wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'XTerm']) {
        echo "\033[33mWARN\033[0m\t${message}"
    }
}

def error(String message) {
    wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'XTerm']) {
        echo "\033[31mERROR\033[0m\t${message}"
    }
    // this will terminate the job if result is non-zero
    // You don't even have to set the result to FAILURE by hand
    sh "exit 1"
}
