######################################
##                                  ##
## Copyright Michal Kawalec, 2013   ##
##                                  ##
##                                  ##
## Ten kod dedykuję Ewci <3         ##
##                                  ##
######################################

stack = ->
    that = {}

    store = []

    that.push = (item) ->
        store.push(item)

    that.pop = ->
        if store.length == 0
            return undefined

        item = store[store.length-1]
        store.splice(store.length-1, 1)

        return item

    return that

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
        that = arguments[1] ? {}

        if singleton.prototype.cached? and \
            singleton.prototype.cached[fn]?
                return _.extend {}, singleton.prototype.cached[fn], that

        if not singleton.prototype.cached?
            singleton.prototype = {}
            singleton.prototype.cached = {}
        singleton.prototype.cached[fn] = (_.partial fn, arguments)()

        return _.extend {}, singleton.prototype.cached[fn], that

helpers = singleton((spec) ->
    that = {}

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

    that.is_number = (data) ->
        return not isNaN(parseFloat(data)) and isFinite(data)

    that.random_string = (length=12) ->
        ret = []
        for i in [0...length]
            ret.push chars[Math.floor(chars.length*Math.random())]
        return ret.join ''

    that.deep_copy = (obj) ->
        if Object.prototype.toString.call(obj) == '[object Array]'
            ret = []
            for el in obj
                ret.push(that.deep_copy(el))
            return ret
        else if typeof obj == 'object'
            ret = {}
            for param, value of obj
                ret[param] = that.deep_copy(value)
            return ret

        return obj

    # TODO: Deal with parameter arrays ie. 
    # pull ?arr[]=first&arr[]=second into
    # arr = ['first', 'second']
    that.pull_params = (route) ->
        addr = route.split('?')[0]
        params = {}

        if route.split('?').length > 1
            raw_params = route.split('?')[1].split('&')
            for param in raw_params
                params[decodeURIComponent(param.split('=')[0])] = \
                    decodeURIComponent(param.split('=')[1])

        return [addr, params]

    that.add_params = (route, params) ->
        if Object.prototype.toString.call(params) == '[object Array]' \
            and params.length == 1 and typeof params[0] == 'object'
                params = params[0]

        if Object.prototype.toString.call(params) == '[object Array]'
            for param,i in params
                if i == 0 and '?' not in route
                    route += '?'
                else
                    route += '&'
                route += 'param'+i+'='+encodeURIComponent(param)
        else if typeof params == 'object'
            i = 0
            for key, value of params
                if i == 0 and '?' not in route
                    route += '?'
                else
                    route += '&'
                route += "#{ encodeURIComponent(key) }=#{ encodeURIComponent(value) }"
                i += 1

        return route

    that.delay = (fn) ->
        setTimeout(fn, 0)

    return that
)

gettext = singleton((spec, that) ->
    if spec[0]?
        spec = spec[0]
    that = that ? {}

    lang = spec.lang ? ($('html').attr('lang') ? 'en')
    lang = if lang.length == 0 then 'en' else lang
    default_lang = spec.default_lang ? 'en'

    static_prefix = spec.static_prefix ? ''
    translations_url = spec.translations_url ? "#{ spec.base_url+static_prefix }translations/"
    if translations_url.indexOf('://') == -1
        translations_url = spec.base_url + translations_url

    translations = {}

    that.gettext = (text, new_lang=lang) ->
        if translations[new_lang] == undefined
            if new_lang != default_lang
                getlang(new_lang)
            else
                return text

        if translations[new_lang] == null
            return text

        if not translations[new_lang][text]?
            return text
        return translations[new_lang][text]

    getlang = (to_get) ->
        p.open {
            url: "#{ translations_url+to_get }.json"
            async: false
            success: (data) ->
                translations[to_get] = data
            error: (data) ->
                if data.status == 404
                    translations[to_get] = null
            palantir_timeout: 3600*48
        }

    inheriter = _.partial init, gettext, that, spec
    p = inheriter palantir

    return that
)

notifier = (spec, that) ->
    that = that ? {}
    _helpers = helpers(spec)

    placeholder = $('#alerts')

    that.notify = (req_data) ->
        if not messages.get_message(req_data)?
            if messages.get_code_message(req_data.status)?
                show_message(messages.get_code_message, req_data.status)
                return
            return

        show_message(messages.get_message, req_data)

    that.extend_code_messages = (data) ->
        messages.extend_code_messages data

    that.extend_messages = (data) ->
        messages.extend_messages data
          
    show_message = (fn, key) ->
        alert = $('<div/>', {
            class: "alert alert-#{ fn(key).type }"
        })

        close_button = $('<button/>', {
            class: 'close'
            'data-dismiss': 'alert'
            text: 'x'
        })
        close_button.on 'click', (e) ->
            alert.hide 'slide',  ->
                for el in placeholder.find('.ui-effects-wrapper')
                    placeholder[0].removeChild el

        message_wrapper = $('<div/>', {
            class: 'message_wrapper'
            text: fn(key).message
        })

        alert.append close_button
        alert.append message_wrapper
        alert.hide()

        placeholder.append alert
        alert.show 'slide'

    inheriter = _.partial init, notifier, that, spec
    p = inheriter(palantir)
    __ = p.gettext.gettext

    messages = (singleton ->
        code_messages = {
            500: {
                type: 'error'
                message: __ 'An internal server error has occured'
            }
            0: {
                type: 'error'
                message: __ 'An unspecified communication error has occured'
            }
        }

        messages = {
            1: {
                type: 'success'
                message: __ 'The action has succeeded'
            }
        }

        that = {}

        that.get_code_message = (code) ->
            return code_messages[code]

        that.get_message = (code) ->
            return messages[code]

        that.extend_code_messages = (data) ->
            _.extend code_messages, data

        that.extend_messages = (data) ->
            _.extend messages, data

        return that
    )()

    return that

template = (spec, that) ->
    that = that ? {}
    if spec[0]?
        spec = spec[0]

    trans_regex = /{%(.*?)%}/g
    spec_regex = /{{(.*?)}}/g

    _libs = {}
    _.extend _libs, helpers(spec)

    static_prefix = spec.static_prefix ? ''
    template_url = spec.template_url ? "#{ spec.base_url+static_prefix }templates/"
    if template_url.indexOf('://') == -1
        template_url = spec.base_url + template_url

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
                target = $(e.target)
                _helpers.delay ->
                    if target.attr('data-prevent_default') == 'true'
                        return

                    data = {}
                    if target.attr('data-silent') != 'false'
                        data.silent = true
                    if string_id?
                        data.string_id = string_id

                    if data.silent != true
                        _validators.hide()

                    _libs.goto target.attr('data-click'), data

        for element in $(where).find('[data-source]')
            ((element) ->
                if $(element).attr('data-actions')?
                    actions = JSON.parse $(element).attr('data-actions')
                that.set_details element, null, actions
            )(element)

        for element in $(where).find("[data-wysiwyg='true']")
            editor = new nicEditor()
            element = $(element)

            editor.panelInstance element.attr('id')

            # Make the validators observe the correct field
            inner_area = (nicEditors.findEditor element.attr('id')).\
                getElm()
            $(inner_area).attr('data-validators', 
                element.attr('data-validators'))
            element.attr('data-validators', '')
            $(inner_area).css 'min-height', '320px'
           

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

                data_tag = $(element).attr('data-tag')
                if data_tag?
                    if tag_renderers.get(data_tag)?
                        tag_renderers.get(data_tag) element, data
                    else tag_renderers.get('div') element, data
                else
                    if not element.tagName?
                        tag_renderers.get('div') element, data, contents
                    else
                        tag_name = element.tagName.lower()
                        if tag_renderers.get(tag_name)?
                            tag_renderers.get(tag_name) element, data
                        else tag_renderers.get('div') element, data

                if actions? and actions.add
                    _libs.open {
                        url: $(element).attr('data-source') + 'spec/'
                        success: (data) ->
                            add_element element, data 
                    }
        }

    tag_renderers = (singleton ->
        _that = {}

        _renderers = {
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

        _that.get = (renderer) ->
            return _renderers[renderer]

        _that.extend = (to_extend) ->
            _.extend _renderers, to_extend

        return _that
    )()

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
            url: template_url + name 
            success: (data) ->
                data = that.parse data
                where.html data

                if action == 'edit'
                    that.bind where, object, string_id
                    fill where, string_id
                else
                    that.bind where, object

                _validators.discover where
            tout: 3600*48
        }

    that.extend_renderers = (extensions) ->
        tag_renderers.extend extensions

    that.extend_renderers spec.tag_renderers
    
    inheriter = _.partial init, template, that, spec
    _.extend _libs, inheriter palantir
    _helpers = inheriter helpers
    _notifier = inheriter notifier 
    _validators = inheriter validators
    __ = inheriter(gettext).gettext

    return that

cache = singleton((spec) ->
    that = {}
    _helpers = helpers(spec)

    timeout = spec.timeout ? 1800

    # A cache object structure:
    # obj = {
    #   expires: int
    #   payload: Object
    # }
    _cache = {}
    dirty = false

    has_timeout = (data) ->
        now = (new Date()).getTime()

        if now > data.expires
            return true
        return false

    that.get = (key) ->
        if _cache[key]
            if has_timeout(_cache[key])
                that.delete(key)
            else if _cache[key] != undefined
                return _helpers.deep_copy(_cache[key].payload)
        return undefined

    that.set = (key, value, new_timeout=timeout) ->
        payload = {
            expires: (new Date()).getTime()+1000*new_timeout
            payload: value
        }
        _cache[key] = payload
        dirty = true

        return key

    that.delete = (key) ->
        delete _cache[key]
        return undefined

    that.genkey = (data) ->
        to_join = ["type:#{ data.type }", "url:#{ data.url }",
            "data: #{ JSON.stringify(data.data) }"]
        return to_join.join ';'

    that.delall = (url) ->
        model_url = url
        if url[url.length-1] != '/'
            index = url.split('').reverse().join('').indexOf('/')
            model_url = url.slice(0, url.length-index)

        searched = "url:#{ url }"
        searched_model = "url:#{ model_url };"
        for key,value of _cache
            if key.indexOf(searched) != -1 or \
                key.indexOf(searched_model) != -1
                    dirty = true
                    delete _cache[key]

    prune_old = (percent=20) ->
        now = (new Date()).getTime()
        keys = []

        for key, value of _cache
            keys.push({key: key, delta_t: value.expires-now})

        keys = _.sortBy keys, (item) -> item.delta_t

        for i in [0...(keys.length*percent/100)]
            delete _cache[keys[i].key]

    persist = ->
        if dirty == true
            try
                localStorage['palantir_cache'] = JSON.stringify(_cache)
                dirty = false
            catch e
                if e.name == 'QuotaExceededError'
                    prune_old()
                    persist()

    # Periodiacally backup to the locaCache to provide
    # data persistence between reloads
    backup_job = setInterval(persist, 1000)

    # Load from the localStorage and set up stuff
    setTimeout((() ->
        if not localStorage?
            window.clearInterval backup_job
            return

        if localStorage['palantir_cache']?
            _cache = JSON.parse(localStorage['palantir_cache'])
    ), 0)

    return that
)

validators = (spec, that) ->
    that = that ? {}
    _helpers = helpers spec

    # The fields managed by this code
    managed = {}
    # The submit handlers
    handlers = {}
    # Validations error display methods
    display_methods = (singleton ->
        _that = {}
        _methods = {}

        _that.get = (id) ->
            return _methods[id]

        _that.all = ->
            return _methods

        _that.extend = (to_extend, overwrite=false) ->
            if not overwrite 
                extend_with = _.omit(to_extend, _.keys(_methods)) 
            else 
                extend_with = to_extend

            _.extend(_methods, extend_with)

        return _that
    )()

    validators_db = (singleton ->
        _that = {}
        _validators = {
            length: (object, kwargs, args...) ->
                kwargs.min = kwargs.min ? (args[0] ? 0)
                kwargs.max = kwargs.max ? (args[1] ? Number.MAX_VALUE)
                errors = []

                value = if object.value? then object.value else $(object).text()
                length = $.trim(value).length

                # The following is oddly formatted thanks to babel being stupid
                if length < kwargs.min
                    errors.push(__("The input of length ") + length + \
                        __(' you entered is too short. The minimum length is ')+ \
                        kwargs.min )
                if length > kwargs.max
                    errors.push(__("The input of length ") + length + \
                        __(' you entered is too long. The maximum length is ')+ \
                        kwargs.min )
                return errors

            email: (object, kwargs, args...) ->
                regex = kwargs.regex if kwargs.regex? else \
                    /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/
                if not $.trim(object.value).match regex
                    return [__('The email you entered is incorrect')]
                return null

            required: (object) ->
                value = if object.value? then object.value else $(object).text()
                if $.trim(value).length == 0
                    return [__('This field is obligatory')]
                return null

            decimal: (object) ->
                value = $.trim(object.value).replace ',', '.'
                value = value.replace ' ', ''

                decimal_regex = /^[0-9]+(\.[0-9]+)?$/
                if decimal_regex.test(value) == false
                    return [__('This doesn\'t look like a number')]

                if object.value != value
                    object.value = value
                return null
        }

        _that.apply = (validator, params) ->
            if _validators[validator] == undefined
                return undefined
            return _validators[validator].apply null, params

        _that.extend = (to_extend) ->
            _.extend _validators, to_extend

        _that.get = ->
            return _validators
        return _that
    )()

    that.discover = (where) ->
        if not where?
            where = spec.placeholder

        for form in where.find('.form')
            form = $(form)
            if not form.attr('data-validation_id')?
                form.attr 'data-validation_id', _helpers.random_string()
            fields = {}

            for field in form.find('[data-validators]')
                field = $(field)
                field.attr 'data-validation_id', _helpers.random_string()
                validators = []
                parsers = []

                for validator in parse_validators(field[0])
                    validators.push validator
                for parser in parse_validators(field[0], 'data-parsers')
                    parsers.push parser

                methods = {
                    validators: validators
                    parsers: parsers
                }
                fields[field.attr('data-validation_id')] = methods
            
            for handler in form.find("[data-submit='true']")
                handler = $(handler)
                if not handler.attr('data-validation_id')?
                    handler.attr 'data-validation_id', _helpers.random_string()

                handlers[handler.attr('data-validation_id')] = \
                    form.attr('data-validation_id')

            form.on 'keyup', 'input,textarea,.nicEdit-main', field_changed

            managed[form.attr('data-validation_id')] = fields

            form.on 'click', "[data-submit='true']", submit_handler
            form.on 'submit', submit_event_handler

    field_changed = (e) ->
        # Handles rechecking the field if its contents changed
        validation_id = $(e.target).attr('data-validation_id')
        for id,fields of managed
            if fields[validation_id] != undefined
                errors = test managed[id], validation_id
                return display_errors errors, validation_id

    display_errors = (errors, current_id) ->
        for name,method of display_methods.all()
            method.create errors, current_id

    submit_handler = (e) ->
        id = handlers[$(e.target).attr('data-validation_id')]
        if not id? then return

        errors = test managed[id]
        if errors.length > 0
            $(e.target).attr('data-prevent_default', 'true')
            display_errors errors
        else
            $(e.target).attr('data-prevent_default', 'false')

    submit_event_handler = (e) ->
        e.preventDefault()
        submit_handler e

    that.init = that.discover

    that.extend = (to_extend) ->
        validators_db.extend to_extend

    that.extend_display_methods = (methods, overwrite) ->
        display_methods.extend methods, overwrite

    that.test = ->
        errors = {}
        for id,fields of managed
            errors[id] = test fields
        return errors

    that.hide = ->
        # Enforce hiding of all validators
        for name,method of display_methods.all()
            method.hide()

    inheriter = _.partial init, validators, that, spec
    p = inheriter palantir

    __ = p.gettext.gettext

    parse_validators = (field, attr='data-validators') ->
        to_parse = $(field).attr(attr)
        if not to_parse?
            return []

        parsed = []

        for validator in to_parse.split(';')
            split = validator.split('(')
            name = $.trim split[0]

            # The dictionary on position 1 holds named params
            ret_params = [field, {}]

            if split.length > 1
                split[1] = $.trim split[1]
                params = split[1].slice(0, split[1].length-1)
                for param in params.split(',')
                    param = ($.trim(param)).split('=')
                    if param.length > 1
                        tmp = {}
                        tmp[param[0]] = param[1]
                        _.extend ret_params[1], tmp
                    else
                        ret_params.push(param[0])

            parsed.push {method: name, params: ret_params}

        return parsed

    test = (fields, current_id) ->
        errors = []
        for id,methods of fields
            errors.push.apply(errors, test_field(id, methods, current_id))
        return errors

    test_field = (id, methods, current_id) ->           
        errors = []

        # The parsers are applied before validators.
        # We are not interested in their output
        for parser in methods.parsers
            validators_db.apply parser.method, parser.params

        for validator in methods.validators
            err = validators_db.apply validator.method, validator.params
            if err? and err.length > 0
                if not current_id? or current_id == id
                    $(validator.params[0]).addClass 'validation-error'
                errors.push {
                    field: id
                    errors: err
                }
            else if not current_id? or current_id == id
                $(validator.params[0]).removeClass 'validation-error'

        return errors

    return that
        
model = (spec={}, that={}) ->
    autosubmit = spec.autosubmit ? false

    last_params = null
    data_def = null
    managed = []

    # Subsequent ids when called with more
    steps = []
    step_index = -1

    created_models = (singleton ->
        _that = {}
        _models = []

        _that.add = (new_model) ->
            _models.push new_model

        _that.get = ->
            return _models
        return _that
    )()

    that.get = (callback, params, error_callback) ->
        params = params ? {}

        url = spec.url
        if params.id?
            url += params.id
            delete params.id

        that.keys -> 
            p.open {
                url: url
                data: params
                success: (data) ->
                    ret = []
                    if Object.prototype.toString.call(data.data) == '[object Array]'
                        for obj in data.data
                            ret.push makeobj obj
                    else
                        ret = makeobj data.data

                    managed.push.apply(managed, ret)

                    other_params = {}
                    for key,value of data
                        if key != 'data'
                            other_params[key] = value

                    callback ret, other_params
                error: error_callback
                palantir_timeout: 300
            }

    that.more = (callback, params) ->
        params = params ? last_params
        if step_index > -1
            params.after = steps[step_index]
        else if params.after?
            delete params.after

        saver = ->
            if step_index+1 == steps.length
                steps.push ret[ret.length-1][spec.id]
            step_index += 1

            callback arguments

        that.get saver, last_params

    that.less = (callback, params) ->
        params = params ? {}

        if step_index < 1 and params.after?
            delete params.after
        else if step_index > 0
            params.after = steps[step_index-2]

        saver = ->
            step_index -= 1
            callback arguments

        that.get saver, params

    that.submit = (callback) ->
        for el in (_.filter managed, (item) -> if item? then true else false)
            if el.__dirty == true
                el.__submit callback

    that.submit_all = (callback) ->
        for model in created_models.get()
            model.submit callback

    that.delete = (object, callback) ->
        object.__delete callback

    that._all_models = ->
        return created_models.get()

    that.new = (callback) ->
        that.keys ->
            new_def = _helpers.deep_copy(data_def)
            for key, value of new_def
                new_def[key] = undefined
            ret = makeobj(new_def, true)

            managed.push(ret)

            callback ret

    that.keys = (callback) ->
        p.open {
            url: spec.url + 'spec/'
            success: (data) ->
                data_def = normalize data.data
                callback _.keys data.data
        }

    that.init = (params) ->
        spec.id = params.id ? 'string_id'
        spec.url = params.url

        if spec.url.indexOf('://') == -1
            spec.url = spec.base_url + spec.url
        if spec.url[spec.url.length-1] != '/'
            spec.url += '/'

        created_models.add that

        return model spec

    makeobj = (raw_object, dirty=false) ->
        ret = {}
        deleted = false

        for prop,value of raw_object
            if typeof value == 'object'
                ret[prop] = value
                continue

            ((prop) ->
                set_value = value
                Object.defineProperty(ret, prop, {
                    set: (new_value) ->
                        check_deletion(deleted)

                        dirty = true
                        set_value = new_value
                    get: ->
                        check_deletion(deleted)
                        return set_value
                })
            )(prop)

        Object.defineProperty(ret, '__dirty', {
            get: -> dirty
            set: (value) -> dirty = value
        })

        ret['__submit'] = (callback, force=false) ->
            if ret.__dirty == false and not force
                return
            check_deletion(deleted)

            that.keys (keys) ->
                data = {}
                for key in keys
                    data[key] = ret[key]
                data = {data: JSON.stringify data}

                req_type = if ret.string_id? then 'PUT' else 'POST'
                url = spec.url

                if req_type == 'PUT'
                    url += ret.string_id

                p.open {
                    url: url
                    data: data
                    type: req_type
                    success: (data) ->
                        for key, value of data.data
                            ret[key] = value
                        ret.__dirty = false

                        callback()
                    error: callback
                }

        ret['__delete'] = (callback) ->
            check_deletion(deleted)

            p.open {
                url: spec.url + ret.string_id
                type: 'DELETE'
                success: (data) ->
                    for el,i in managed
                        if el == ret
                            # Splice is not used for performance reasons
                            managed[i] = undefined
                            break

                    ret = undefined
                    deleted = true
                    callback()
                error: callback
            }

        return ret

    check_deletion = (deleted) ->
        if deleted == true
            throw { 
                type: 'DeletedError'
                message: 'The object doesn\'t exist any more'
            }


    normalize = (data) ->
        for key, value of data
            if value == 'unicode' or value == 'str' or value == 'text'
                data[key] = 'string'
            if value == 'int' or value == 'decimal'
                data[key] = 'number'

        return data

    inheriter = _.partial init, model, that, spec
    p = inheriter palantir
    _helpers = inheriter helpers

    return that

palantir = singleton((spec={}) ->
    that = {}

    if spec[0]?
        spec = spec[0]

    _that = {}
    _.extend _that, helpers(spec)

    # TODO: Make it switchable by spec
    connection_storage = stack()
    running_requests = 0
    max_requests = spec.max_requests ? 4

    spec.placeholder = spec.placeholder ? $('body')

    routes = []

    # Magic generating the base url for the app
    base_url = spec.base_url ? (location.href.match /^.*\//)
    if Object.prototype.toString.call(base_url) == '[object Array]'
        if base_url.length == 0
            base_url = location.href
        else
            base_url = base_url[0]

    if base_url[base_url.length-1] != '/'
        base_url += '/'
    spec.base_url = base_url

    wait_time = spec.wait_time ? 100

    pop_storage = ->
        if running_requests < max_requests
            req = connection_storage.pop()
            if req?
                req()

    request_finished = (fn) ->
        () ->
            running_requests -= 1
            
            pop_storage()
            fn.apply(null, arguments)

    wrap_request = (fn, data) ->
        () ->
            running_requests += 1
            data.error = request_finished data.error
            data.success = request_finished data.success

            fn data

    cached_memoize = (fn, data, new_tout, caching=true) ->
        key = _cache.genkey(data)
        cached = _cache.get(key)

        if cached? and caching and data.type == 'GET'
            if typeof cached.data == 'string'
                return data.success cached.data
            return data.success cached

        _cache.set(key, 'waiting', 15)

        return wrap_request(fn, data)()

    save_cache = (fn, cache_key, new_timeout) ->
                    (data, text_status, request) ->
                        if request? and request.getResponseHeader? and spec.expires != false
                            new_timeout = Date.parse(request.getResponseHeader('Expires'))

                        if not data.req_time?
                            if typeof data == 'string'
                                _cache.set(cache_key, { data: data }, new_timeout)
                            else
                                _cache.set(cache_key, data, new_timeout)

                        fn data
    
    on_error = (fn_succ, fn_err, cache_key) ->
                    (data) ->
                        cached = _cache.get(cache_key)

                        if cached?
                            if cached != 'waiting'
                                return fn_succ cached
                            _cache.delete(cache_key)

                        that.notifier.notify data

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
        args = [$.ajax, req_data, req_data.tout, req_data.caching]

        req_data.error = on_error(req_data.success, req_data.error, key)
        if req_data.type == 'GET' and req_data.palantir_cache != false
            req_data.success = save_cache(req_data.success, key, 
                req_data.palantir_timeout)
            if running_requests >= max_requests
                return connection_storage.push promise(cached_memoize, args,key)
            else
                return promise(cached_memoize, args, key)()

        if running_requests >= max_requests    
            return connection_storage.push wrap_request $.ajax, req_data

        if req_data.type != 'GET'
            _cache.delall req_data.url

        (wrap_request $.ajax, req_data)()


    that.template = (name, where, object={}) ->
        that.templates.open name, where, object

    that.extend_code_messages = (data) ->
        if not that.notifier?
            return

        that.notifier.extend_code_messages data

    that.extend_messages = (data) ->
        if not that.notifier?
            return

        that.notifier.extend_messages data
    
    that.route = (route, fn) ->
        routes.push({route: route, fn: fn})

        () ->
            fn.apply(null, arguments)

    that.goto = (route, params...) ->
        if params.length > 0 and params[0].silent == true
            res = _.where(routes, {route: route})
            for matching in res
                matching.fn params[0]
            return

        route = '#'+that.helpers.add_params route, params
        window.location.hash = route

        ((routes) ->
            hashchange()
        )(routes)
        
    hashchange = (e) ->
        e?.preventDefault()
        e?.stopPropagation()

        [route, params] = that.helpers.\
            pull_params location.hash.slice(1)
        res = _.where(routes, {route: route})

        for matching in res
            matching.fn(params)

    # Constructor
    setTimeout((() ->
        that.extend_code_messages spec.code_messages
        that.extend_messages spec.messages

        $(window).on 'hashchange', (e) ->
            ((routes) ->
                hashchange(e)
            )(routes)

        hashchange()

        $('body').on 'click', 'a[data-route]', (e) ->
            e.preventDefault()
            that.goto($(e.target).attr('data-route'), {target: $(e.target).attr 'id'})
    ), 0)

    inheriter = _.partial init, palantir, that, spec
    _cache = inheriter(cache)

    that.templates = inheriter template
    that.notifier = inheriter notifier
    that.helpers = inheriter helpers
    that.gettext = inheriter gettext
    that.validators = inheriter validators
    that.model = inheriter model

    return that
)

# Exports to global scope
window.palantir = palantir
window.singleton = singleton
window.init = init
