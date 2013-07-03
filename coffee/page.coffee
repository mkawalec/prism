letter = (spec, that) ->
    that = that ? {}
    p = palantir(spec)

    model = p.model.init {
        url: 'http://localhost:5000/signatures/'
    }

    create = p.route 'init', () ->
        extend_messages()

        p.template('header.html', $('#header'))
        p.template('body.html', $('#body'), that)
        $(document).on 'click', '#submit', (e) ->
            email = $.trim $('#email')[0].value
            name = $.trim $('#name')[0].value
            comment = $.trim $('#comment')[0].value
            console.log 'calling?'

            if name.length == 0
                p.notifier.notify 'no_name', $('.podpisz .alerts')
                return

            if email.length == 0
                p.notifier.notify 'no_email', $('.podpisz .alerts')
                return
            else if not email.match /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/
                p.notifier.notify 'email_incorrect', $('.podpisz .alerts')
                return

            model.new (new_obj) ->
                new_obj.email = email
                new_obj.name = name
                new_obj.comment = comment

                model.submit (data) ->
                    if data?.status?
                        p.notifier.notify 'email_duplicate', $('.podpisz .alerts')
                    else
                        p.notifier.notify 'submit_success', $('.podpisz .alerts')

    extend_messages = ->
        p.notifier.extend_messages {
            success: {
                type: 'success'
                message: 'Dziękujemy, twój podpis został potwierdzony!'
            }
            not_found: {
                type: 'error'
                message: 'Nie znaleziono podpisu z takim kodem potwierdzającym'
            }
            submit_success: {
                type: 'success'
                message: 'Twój podpis został tymczasowo zapisany. Kliknij link w mailu by go potwierdzić.'
            }
            no_email: {
                type: 'error'
                message: 'Email jest wymagany'
            }
            no_name: {
                type: 'error'
                message: 'Imię i nazwisko są wymagane'
            }
            email_duplicate: {
                type: 'error'
                message: 'Ten email już złożył podpis'
            }
            email_incorrect: {
                type: 'error'
                message: 'Ten email jest niepoprawny'
            }
        }

    signatures = ->
        model.get ((data, other) ->
            $('#number_of_sigs').text "#{ other.amount } podpisów"
        ), {limit: 5}

    confirm = p.route 'confirm', (params) ->
        create()

        $.ajax {
            url: "http://localhost:5000/" + "confirm/#{ params.code }"
            type: 'POST'
            success: ->
                p.notifier.notify 'success'
            error: (data) ->
                if data.status == 404
                    p.notifier.notify 'not_found'
                else
                    p.notifier.notify data
        }

    # Constructor
    setTimeout((() ->
        hash = location.hash
        if hash.length == 0 or hash == '#init'
            p.goto('init')
        signatures()
    ), 0)

    inheriter = _.partial init, letter, that, spec

    return that


open_letter = letter({expires: false})

