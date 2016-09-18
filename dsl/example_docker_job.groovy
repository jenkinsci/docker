job('Example with docker') {
    steps {
        shell('''
            set +x

            docker version || KO=1
            
            if [ "$KO" -eq "1" ]; then
                echo -e "\\n\\ndocker is not available, see https://goo.gl/RpkBZz\\n\\n"
                exit 1
            else
                echo -e"\\n\\ndocker is available\\n\\n"
                docker images
            fi
        '''.stripIndent())
    }
}