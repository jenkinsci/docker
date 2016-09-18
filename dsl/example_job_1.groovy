job('Example 1') {
    steps {
        shell('''
        	echo "hello world"
    	'''.stripIndent())
    }
}