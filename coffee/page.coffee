letter = (spec, that) ->
    that = that ? {}
    p = palantir(spec)

    _signatures = signatures(spec)

    create = p.route('init', () ->
        p.template('header.html', $('#header'))
        p.template('body.html', $('#body'), that)
    )

    # Constructor
    setTimeout((() ->
        p.goto('init')
        _signatures.create()
    ), 0)

    inheriter = _.partial init, letter, that, spec

    return that

signatures = (spec, that) ->
    that = that ? {}
    p = palantir(spec)

    model = p.model.init {
        url: 'http://localhost:5000/signatures/'
    }

    that.create = ->
        console.log spec.base_url
        model.get ((data) ->
            console.log data
        ), {limit: 5}

    return that

open_letter = letter({expires: false})

