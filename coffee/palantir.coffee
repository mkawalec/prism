##############################
##                          ##
## Ten kod dedykuję Ewci <3 ##
##                          ##
##############################

# TODO: Change the order to be partial-friendly (inherited
# is the last argument)
init = (initiator, public_initiator, spec, inherited) ->
    _helpers = helpers()

    new_id = _helpers.random_string()
    if (not initiator.prototype.call_ids?) and (not initiator.prototype.callers?)
        initiator.prototype = {}

    initiator.prototype.call_ids = initiator.prototype.call_ids ? []
    initiator.prototype.call_ids.push new_id
    initiator.prototype.call_that = public_initiator

    if (not inherited.prototype.callers?) and (not inherited.prototype.call_ids?)
        inherited.prototype = {}
    inherited.prototype.callers = inherited.prototype.callers ? []
    inherited.prototype.callers.push(new_id)
    
    if inherited.prototype.call_ids?
        if (_.intersection initiator.prototype.callers, inherited.prototype.call_ids).length > 0
            return inherited.prototype.call_that
    return inherited spec

singleton = (fn) ->
    return () ->
        if singleton.prototype.cached? and \
            singleton.prototype.cached[fn]?
                return singleton.prototype.cached[fn]

        if not singleton.prototype.cached?
            singleton.prototype = {}
            singleton.prototype.cached = {}
        singleton.prototype.cached[fn] = (_.partial fn, arguments)()
        return singleton.prototype.cached[fn]

helpers = singleton((spec, that) ->
    that = that ? {}

    chars = 'abcdefghijklmnoprstuwqxyzABCDEFGHIJKLMNOPRSTUWQXYZ0123456789'

    _props = ['id', 'data-source', 'data-actions', 
        'data-shown_property', 'data-binding']
   
    that.clone = (element) ->
        tag_name = element.tagName.lower()

        clone = $("<div/>", {
            class: tag_name
            'data-tag': tag_name
        })

        _.each _props, (prop) ->
            $(clone).attr(prop, $(element).attr(prop))
        $(element).replaceWith clone
        return clone

    that.classify = (action) ->
        switch action
            when 'info' then return 'info'
            when 'edit' then return 'warning'
            when 'delete' then return 'danger'

    that.name = (action) ->
        switch action
            when 'delete' then return __ 'Delete'
            when 'info' then return __ 'Info'
            when 'edit' then return __ 'Edit'
        return __ action

    that.is_number = (data) ->
        return not isNaN(parseFloat(data)) and isFinite(data)

    that.random_string = (length=12) ->
        ret = []
        for i in [0...length]
            ret.push chars[Math.floor(chars.length*Math.random())]
        return ret.join ''

    return that
)

notifier = (spec, that) ->
    that = that ? {}

    placeholder = $('#alerts')

    that.notify = (req_data) ->
        if not messages[req_data]?
            if code_messages[req_data.status]?
                show_message(code_messages, req_data.status)
                return
            return

        show_message(messages, req_data)
          
    show_message = (messages, key) ->
        alert = $('<div/>', {
            class: "alert alert-#{ messages[key].type }"
        })

        close_button = $('<button/>', {
            class: 'close'
            'data-dismiss': 'alert'
            text: 'x'
        })
        close_button.on 'click', (e) ->
            alert.hide 'slide', 'fast', ->
                for el in placeholder.find('.ui-effects-wrapper')
                    placeholder[0].removeChild el

        message_wrapper = $('<div/>', {
            class: 'message_wrapper'
            text: messages[key].message
        })

        alert.append close_button
        alert.append message_wrapper
        alert.hide()

        placeholder.append alert
        alert.show 'slide', 'fast'

    code_messages = {
        500: {
            type: 'error'
            message: 'Nastąpił błąd serwera. Sprawa jest badana...'
        }
    }

    messages = {
        1: {
            type: 'success'
            message: __ 'The action has succeeded'
        }
    }

    return that

template = (spec, that) ->
    that = that ? {}
    if spec[0]?
        spec = spec[0]

    trans_regex = /{%(.*?)%}/g
    spec_regex = /{{(.*?)}}/g

    _libs = {}
    _.extend _libs, helpers(spec)

    base_url = spec.base_url ? url_root
    spec.base_url = base_url

    translate = (_, text) ->
        return __ $.trim text

    get_spec = (_, text) ->
        return spec[$.trim(text)]

    add_element = (element, data) ->
        $(element).parent().append(
            "<button class='btn btn-success add'>"+\
            "<i class='icon-plus'></i></button>")
        add_btn = $(element).siblings '.add'

        $(add_btn).on 'click', (e) ->
            e.preventDefault()
            modal = new Modal __ 'Add'
            modal.add_form()

            for field in _.keys data.data
                switch data.data[field]
                    when 'str'
                        modal.add_field field
                    when 'unicode'
                        modal.add_field field
                    when 'int'
                        attrs = {'data-parser': 'Decimal'}
                        modal.add_field field, attrs
                    when 'Decimal'
                        attrs = {'data-parser': 'Decimal'}
                        modal.add_field field, attrs

            btn = modal.add_button 'info', __ 'Add'
            $(btn).on 'click', (e) ->
                data = {}
                for field in $(modal.get()).find('.form-horizontal').find('input')
                    data[$(field).attr('data-binding')] = $.trim field.value

                _libs.open {
                    url: $(element).attr('data-source')
                    type: 'POST'
                    data: data
                    success: (data) ->
                        modal.hide()
                        that.set_details element, false
                }

            modal.show()

    that.parse = (body) ->
        body = body.replace trans_regex, translate
        body = body.replace spec_regex, get_spec

        return body

    that.bind = (where, actions_object, string_id) ->
        for element in where.find('[data-click]')
            $(element).on 'click', (e) ->
                e.preventDefault()
                if string_id?
                    actions_object[$(@).attr('data-click')](string_id)
                else
                    actions_object[$(@).attr('data-click')]()

        for element in $(where).find('[data-source]')
            ((element) ->
                if $(element).attr('data-actions')?
                    actions = JSON.parse $(element).attr('data-actions')
                that.set_details element, null, actions
            )(element)

        for element in $(where).find('[data-wysiwyg]')
            if $(element).attr('data-wysiwyg') == 'true'
                editor = new nicEditor()
                editor.panelInstance $(element).attr('id')

    that.set_details = (element, caching=true, actions) ->
        _libs.open {
            url: $(element).attr('data-source')
            caching: caching
            success: (data) ->
                # Remove all children
                contents = $(element).html()
                $(element).html('')
                if contents == 'null'
                    return $(element).html(__ 'No category')

                if $(element).attr('data-tag')?
                    tag_renderers[$(element).attr('data-tag')] element, data
                else
                    if not element.tagName?
                        tag_renderers.div element, data, contents
                    else
                        tag_renderers[element.tagName.lower()] element, data

                if actions? and actions.add
                    _libs.open {
                        url: $(element).attr('data-source') + 'spec/'
                        success: (data) ->
                            add_element element, data 
                    }
        }

    tag_renderers = {
        select: (element, data) ->
            for el in data.data
                $(element).append($("<option/>", {
                    value: el.string_id
                    text: el[$(element).attr('data-shown_property')]
                }))

        div: (element, data, contents) ->
            for el in data.data
                if el.string_id == contents
                    $(element).html el[$(element).attr('data-binding')]
                    break

        imagelist: (element, data, clear=true, offset=0) ->
            _imagelist = imagelist({element: element})
            if clear
                _imagelist.create(data)
            else
                _imagelist.render(data, offset)

        checklist: (element, data) ->
            element = _helpers.clone(element)

            $(element).on 'change', 'input', (e) ->
                selected = []
                for el in $(e.delegateTarget).\
                    find("input[type='checkbox']:checked")
                        selected.push(el.value)

                $(e.delegateTarget).\
                    attr('data-value', JSON.stringify(selected))

            # For all elements
            for el in data.data
                id = _libs.random_string()

                checkbox_group = $('<div/>', {
                    class: 'checkbox-group'
                })
                blah = checkbox_group.append($("<input/>", {
                    type: 'checkbox'
                    value: el.string_id
                    id: id
                }))
                checkbox_group.append($('<label/>', {
                    for: id
                    text: el[$(element).attr('data-shown_property')]
                }))

                element.append(checkbox_group)
    }
    _.extend tag_renderers, spec.tag_renderers

    fill = (where, string_id) ->
        _libs.open {
            url: spec.url+string_id
            success: (data) ->
                for column, details of data.data
                    col = $("[data-binding='#{ column }']")
                    if col.attr('data-wysiwyg') != 'true'
                        col.val(details)
                    else
                        editor = nicEditors.findEditor(col.attr('id'))
                        editor.setContent(details)
        }

    that.open = (name, where, object, action='add', string_id) ->
        _libs.open {
            url: base_url + "static/templates/#{ name }"
            success: (data) ->
                data = that.parse data
                where.html data

                if action == 'edit'
                    that.bind where, object, string_id
                    fill where, string_id
                else
                    that.bind where, object

            tout: 3600
        }
    
    inheriter = _.partial init, template, that, spec
    _.extend _libs, inheriter(palantir)
    _helpers = inheriter(helpers)
    _notifier = inheriter(notifier)

    return that

imagelist = (spec, that) ->
    that = that ? {}

    element = null
    images = null
    controls = null
    root = null
    img_type = /image.*/

    that.create = (data) ->
        element = _helpers.clone(spec.element)
        root = $(element).attr('data-source')

        images = $('<div/>', {
            class: 'images'
        })
        controls = $('<div/>', {
            class: 'controls'
        })
        element.append images
        element.append controls

        if data.more
            controls.append($('<button/>', {
                class: 'btn btn-more btn-large'
                html: $('<i/>', {class: 'icon-plus'})
            }))

        controls.append($('<input/>', {
            type: 'file'
            id: 'image-upload'
            style: 'display:none;'
            multiple: 'true' 
            accept: "image/*"
        }))
        controls.find('#image-upload').on 'change', add_image

        controls.append($('<button/>', {
            class: 'btn btn-success btn-upload btn-large'
            html: $('<i/>', {class: 'icon-upload'})
        }))
        controls.find('button.btn-upload').on 'click', (e) ->
            e.preventDefault()
            $('#image-upload').click()

        that.render(data, 0)

    add_image = (event) ->
        for file in @files
            if not file.type.match img_type
                continue
            img = $('<div/>', {
                class: 'image'
            })

            image = $('<img/>')
            img.append image
            images.prepend img
            image[0].file = file

            reader = new FileReader()
            ((image) ->
                $(reader).on 'load', (e) ->
                    image[0].src = e.target.result
            )(image)
            reader.readAsDataURL(file)

            $(img).append($('<div/>', {
                class: 'loader'
            }))

            fd = new FormData()
            fd.append('image', file)

            ((loader, image) ->
                _palantir.open {
                    url: root
                    type: 'POST'
                    data: fd
                    xhr: ->
                        xhr = $.ajaxSettings.xhr()
                        xhr.upload.addEventListener 'progress',((e) ->
                            prog = e.loaded/e.total*100
                            loader.attr 'style', "top:#{ prog }%"), false
                        $(xhr.upload).on 'load', (e) ->
                            loader.attr 'style', "top:100%"
                        return xhr
                    contentType: false
                    processData: false
                    success: (data) ->
                        $(image).attr('data-src', data.string_id)
                        make_clickable image
                }
            )($(img).find('.loader'), image)

    that.render = (data, offset) ->         
        btn_more = controls.find('button.btn-more')
        btn_more.off 'click'
        btn_more.on 'click', (e) ->
            e.preventDefault()

            _palantir.open {
                url: root + "?offset=#{ offset+20 }"
                success: (data) ->
                    that.render(data, offset+20)
            }


        if data.more == false
            controls.find('button.btn-more').hide()

        for img in data.data
            wrapper = $('<div/>', {
                class: 'image'
            })
            images.append wrapper

            ((wrapper, addr, string_id) ->
                _palantir.open {
                    url: addr+'?base64=true&dimx=150&dimy=150'
                    success: (data) ->
                        image = new Image()
                        image.src = 'data:image/jpeg;base64,'+data
                        $(image).attr 'draggable', 'true'
                        $(image).attr 'data-src', string_id

                        $(image).on 'dragstart', (e) ->
                            @.src = addr+'?dimx=400&dimy=400'

                        wrapper.append image
                        make_clickable image
                }
            )(wrapper, root+img.string_id, img.string_id)

    make_clickable = (image) ->
        $(image).on 'click', (e) ->
            addr = root+$(image).attr('data-src')
            modal = new Modal(__('Image details'))

            modal.set_body($('<img/>', {
                src: addr+'?dimx=558&dimy=558'
                class: 'img-preview'
            }))
            modal.set_body($('<div/>', {
                class: 'img-info'
                html: $('<input/>', { 
                    type: 'text'
                    class: 'input input-xxlarge img-addr'
                    value: addr+'?dimx=400&dimy=400' })
            }))
            input = $(modal.get()).find('.img-addr')
            input.on 'click', (e) ->
                e.preventDefault()
                @select()

            modal.show()

    inheriter = _.partial init, imagelist, that, spec
    _helpers = inheriter(helpers)
    _palantir = inheriter(palantir)

    return that

cache = singleton((spec, that) ->
    that = that ? {}
    timeout = spec.timeout ? 60

    # A cache object structure:
    # obj = {
    #   expires: int
    #   payload: Object
    # }
    cache = {}
    dirty = false

    has_timeout = (data) ->
        now = (new Date()).getTime()

        if now > data.expires
            return true
        return false

    that.get = (key) ->
        if cache[key]
            if has_timeout(cache[key])
                that.delete(key)
            else    
                return cache[key].payload
        return undefined

    that.set = (key, value, new_timeout=timeout) ->
        payload = {
            expires: (new Date()).getTime()+1000*new_timeout
            payload: value
        }
        cache[key] = payload
        dirty = true

        return key

    that.delete = (key) ->
        delete cache[key]
        return undefined

    that.genkey = (data) ->
        return data.type+data.url+JSON.stringify(data.data)

    # Periodiacally backup to the locaCache to provide
    # data persistence between reloads
    backup_job = setInterval((() ->
        if dirty == true
            localStorage['palantir_cache'] = JSON.stringify(cache)
            dirty = false
    ), 1000)

    # Load from the localStorage and set up stuff
    setTimeout((() ->
        if not localStorage?
            window.clearInterval backup_job
            return

        if localStorage['palantir_cache']?
            cache = JSON.parse(localStorage['palantir_cache'])
    ), 0)

    return that
)

palantir = singleton((spec, that) ->
    that = that ? {}
    if spec[0]?
        spec = spec[0]

    _that = {}
    _.extend _that, notifier(spec)
    _.extend _that, helpers(spec)

    routes = {}

    tout = spec.timeout ? 120
    base_url = spec.base_url ? url_root
    spec.base_url = base_url

    wait_time = spec.wait_time ? 100

    cached_memoize = (fn, data, new_tout, caching=true) ->
        key = _cache.genkey(data)
        cached = _cache.get(key)

        if cached? and caching and data.type == 'GET'
            if typeof cached.data == 'string'
                return data.success cached.data
            return data.success cached

        _cache.set(key, 'waiting', 15)
        return fn data

    save_cache = (fn, cache_key) ->
                    (data) ->
                        if not data.req_time?
                            if typeof data == 'string'
                                _cache.set(cache_key, { data: data })
                            else
                                _cache.set(cache_key, data)

                        fn data
    
    on_error = (fn_succ, fn_err, cache_key) ->
                    (data) ->
                        cached = _cache.get(cache_key)

                        if cached?
                            if cached != 'waiting'
                                return fn_succ cached
                            delete _cache.delete(cache_key)

                        _that.notify data

                        if fn_err?
                            fn_err data

    promise = (fn, args, key) ->
        () ->
            cached = _cache.get(key)

            if not cached? or cached != 'waiting'
                return fn.apply(null, args)
            if cached == 'waiting'
                setTimeout(promise(fn, args, key), wait_time)

    that.open = (req_data) ->
        if not req_data.type?
            req_data.type = 'GET'

        key = _cache.genkey req_data

        req_data.error = on_error(req_data.success, req_data.error, key)
        if req_data.type == 'GET' and req_data.palantir_cache != false
            req_data.success = save_cache(req_data.success, key)

        args = [$.ajax, req_data, req_data.tout, req_data.caching]
        promise(cached_memoize, args, key)()

    that.template = (name, where, object) ->
        that.open {
            url: base_url + "templates/#{ name }"
            success: (data) ->
                data = _template.parse data
                where.html data

                _template.bind where, object
            tout: 3600*24
        }
    
    that.route = (route, fn) ->
        routes.push({route: route, fn: fn})

        () ->
            fn.apply(null, arguments)

    # Constructor
    setTimeout((() ->
        $(window).on 'hashchange', (e) ->
            e.preventDefault()
            e.stopPropagation()

            res = _.where(routes, {route: window.location.hash.slice(1)})
            if res.length > 0
                res[0].fn()
    ), 0)

    inheriter = _.partial init, palantir, that, spec
    _template = inheriter(template)
    _cache = inheriter(cache)

    return that
)
