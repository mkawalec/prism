fs = require 'fs'

{print} = require 'sys'
{spawn} = require 'child_process'
{writeFile} = require 'fs'
UglifyJS = require("uglify-js")

build = (callback) ->
    ls = spawn 'ls', ['coffee']

    ls.stdout.on 'data', (data) ->
        for row in data.toString().split('\n')
            if not row.match /\.coffee/
                continue
            coffee = spawn 'coffee', ['-p', '-c', '-b', 'coffee/'+row]
            ((row) ->
                coffee.stdout.on 'data', (output) ->
                    final_code = UglifyJS.minify(output.toString(), {fromString: true}).code

                    filename = 'js/'+row.match(/\w*/)[0]+'.js'
                    print 'writing ' + filename + '\n'
                    writeFile filename, final_code, (err) ->
                        if err then throw err

                coffee.stderr.on 'data', (data) ->
                    process.stderr.write data.toString()
                coffee.on 'exit', (code) ->
                    callback?() if code is 0
            )(row)

task 'watch', 'Watch source for changes', ->
    coffee = spawn 'coffee', ['-w', '-c', '-l', '-b', '-o', 'js', 'coffee']
    coffee.stderr.on 'data', (data) ->
        process.stderr.write data.toString()
    coffee.stdout.on 'data', (data) ->
        print data.toString()

task 'build', 'Build from src', ->
    build()
