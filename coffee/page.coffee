letter = (spec, that) ->
    that = that ? {}
    p = palantir(spec)

    create = p.route('init', () ->
        p.template('header.html', $('#header'))
        p.template('body.html', $('#body'), that)
        p.template('footer.html', $('#footer'))
    )

    submit = p.route('submit-sig', (target) ->
        alert 'submitted', target
    )

    # Constructor
    setTimeout((() ->
        create()
    ), 0)

    inheriter = _.partial init, letter, that, spec

    return that

open_letter = letter()
