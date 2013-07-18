letter = (spec, that) ->
    that = that ? {}
    p = palantir(spec)

    model = p.model.init {
        url: 'api/signatures/'
    }

    create = p.route 'init', () ->
        extend_messages()

        p.template('header.html', $('#header'))
        p.template('body.html', $('#body'), that)

        submitted = false
        $(document).on 'click', 'button#submit', (e) ->
            if submitted == true
                e.preventDefault()
                return

            email = $.trim $('#email')[0].value
            name = $.trim $('#name')[0].value
            comment = $.trim $('#comment')[0].value

            if name.length == 0
                p.notifier.notify 'no_name', $('.podpisz .alerts')
                return

            if email.length == 0
                p.notifier.notify 'no_email', $('.podpisz .alerts')
                return
            else if not email.match /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/
                p.notifier.notify 'email_incorrect', $('.podpisz .alerts')
                return

            submitted = true

            model.new (new_obj) ->
                new_obj.email = email
                new_obj.name = name
                new_obj.comment = comment

                model.submit (data) ->
                    if data?.status?
                        p.notifier.notify 'email_duplicate', $('.podpisz .alerts')
                        submitted = false
                        model.delete new_obj
                    else
                        p.notifier.notify 'submit_success', $('.podpisz .alerts')
                        $('button#submit').addClass 'disabled'

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
            $('#number_of_sigs').text "Już #{ other.amount } osób poparło nasz list"
        ), {limit: 1}

    confirm = p.route 'confirm', (params) ->
        create()

        $.ajax {
            url: "#{ spec.base_url }api/confirm/#{ params.code }"
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
        if hash.length == 0
            p.goto('init')
        signatures()
    ), 0)


    return that


open_letter = letter({expires: false})

