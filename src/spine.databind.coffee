Spine      = @Spine
Controller = Spine.Controller

class Template
	keys: [ ]

	bind: (operators,model,controller,el,options) ->
	unbind: (operators,model,controller,el,options) ->

	bindToModel: (operators,model,controller,el,options,event = "update") ->
		model.constructor.bind(event, binder = () => @update(operators,model,controller,el,options))
		controller.bind("destroy-bindings", unbinder = (record) =>
			#if record && model.eql(record)
			model.constructor.unbind(event,binder)
			controller.unbind("destroy-bindings", unbinder)
		)

	bindToElement: (operators,model,controller,el,options,event = "change") ->
		el.bind(event+".spine-databind", binder = () => @change(operators,model,controller,el,options))
		controller.bind("destroy-bindings", unbinder = (record) =>
			el.unbind(event+".spine-databind", binder)
			controller.unbind("destroy-bindings", unbinder)
		)

	get: (item,value,callback) ->
		if typeof item[value] is "function"
			result = item[value](callback)
		else
			result = item[value]
		result

	set: (model,property,value,options) ->
		# Functions are read-only
		return if typeof model[property] is "function"

		if !options or options.save
			model.updateAttribute(property,value)
		else
			model[property] = value

class Update extends Template
	keys: [ "text", "value", "html" ]

	bind: (operators,model,controller,el,options) ->
		@bindToElement(operators,model,controller,el,options)

		if options.watch
			@bindToModel([operator],model,controller,el,options,"update["+operator.property+"]") for operator in operators
		else
			@bindToModel(operators,model,controller,el,options,"change")

		@update(operators,model,controller,el,options)
 
	change: (operators,model,controller,el,options) ->
		binder = @
		el.each () ->
			e = $(@)
			for operator in operators
				switch @tagName
					when "INPUT", "SELECT", "TEXTAREA"
						binder.set(model,operator.property,e.val(), options)
					else
						binder.set(model,operator.property,e.text(), options)
			@
		@

	update: (operators,model,controller,el,options) ->
		binder = @
		el.each () ->
			e = $(@)
			for operator in operators
				value = binder.get(model,operator.property)
				switch @tagName
					when "INPUT", "TEXTAREA"
						if e.val() isnt value
							e.val(value)
							e.trigger("change") 
					when "SELECT"
						# Deselect
						isSelected = e.find(":not(option[value=#{value}]):selected")
						shouldBeSelected = e.find("option[value=#{value}]:not(:selected)")

						if isSelected.length > 0 or shouldBeSelected.length > 0
							isSelected.each((key,element) -> $(element).removeAttr("selected"))
							# Select
							shouldBeSelected.attr("selected","selected")
							# Changed
							e.trigger("change") 
					else
						if typeof value is "object" and value and value.constructor is Array
							formatted = value.join(",")
						else if typeof value is "object" and value
							formatted = value.toString()
						else
							formatted = value

						if operator.name is "html"
							e.html(formatted)
						else
							if e.text() isnt formatted
								e.text(formatted)
								e.trigger("change")
				
			@
		@

class Options extends Template
	keys: [ "options", "selectedOptions" ]

	bind: (operators,model,controller,el,options) ->
		if options.watch
			ops = operators.filter((e) -> e.name is "options")
			opsSelected = operators.filter((e) -> e.name is "selectedOptions")
			together = ops.concat(opsSelected)
			
			# ops
			@bindToModel(together,model,controller,el,options,"update["+ops[0].property+"]") if ops and ops.length is 1
			@bindToModel(together,model,controller,el,options,"update["+opsSelected[0].property+"]") if opsSelected and opsSelected.length is 1
		else
			@bindToModel(operators,model,controller,el,options,"update")

		if operators.some((e) -> e.name is "selectedOptions")
			@bindToElement(operators,model,controller,el,options)

		@update(operators,model,controller,el,options)

	update: (operators,model,controller,el,options) ->
		ops = operators.filter((e) -> e.name is "options")
		opsSelected = operators.filter((e) -> e.name is "selectedOptions")
		selectedOptions = if opsSelected.length is 1 then @get(model,opsSelected[0].property) else [] 
		selectedOptions = [selectedOptions] if not (selectedOptions instanceof Array)

		process = (array) ->
			options = el.children('option')

			if not array
				result = el.find("option").map((index,item) -> return { text: $(item).text(), value: $(item).val() })
			else if array instanceof Array
				result = ({ text: item, value: item} for item in array)
			else
			    result = Object.keys(array)
			                   .map((r) => { text: array[r], value: r })
			                   .sort((a,b) => 
			                   		if (b.value == "")
			                   			return 1
			                   		else if (a.value == "")
			                   			return -1
			                   		else
			                   			return a.text.localeCompare(b.text)
			                   	)

			count = 0
			count = count = count + 1 for own property in result
			changed = false

			for item,index in result
				option = if options.length > index then $(options[index]) else null
				if (!isNaN(item.value-0) and selectedOptions.indexOf((item.value-0)) >= 0) or
				   selectedOptions.indexOf(item.value) >= 0
					selected = "selected='selected'"
				else
					selected = ""

				if option is null
					el.append "<option value='#{item.value}' #{selected}>#{item.text}</option>"
					changed = true
				else
					option.text(item.text) if option.text() isnt item.text
					option.val(item.value) if option.val?() isnt item.value
					if option.attr("selected") is "selected" or option.attr("selected") is true
						if selected.length is 0
							option.removeAttr("selected")
							changed = true
					else
						if selected.length > 0
							option.attr("selected","selected")
							changed = true

			if options.length > count
				for index in [count..options.length]
					$(options[index]).remove()
					changed = true

			el.trigger("change") if changed						

		array = if ops.length is 1 then @get(model,ops[0].property,process) else null

		process(array) if typeof array isnt "function"

	change: (operators,model,controller,el,options) ->
		operator = operators.filter((e) -> e.name is "selectedOptions")[0]
		
		items = []
		el.find("option:selected").each(() ->
			items.push($(this).val())
		)

		value = @get(model,operator.property)

		if value instanceof Array or items.length > 1
			newValue = []
			newValue = newValue.concat(items)
		else
			if items.length is 1
				newValue = items[0]

		@set(model, operator.property, newValue, options)

class Click extends Template
	keys: [ "click" ]

	bind: (operators,model,controller,el,options) ->
		@bindToElement(operators,model,controller,el,options,"click")

	change: (operators,model,controller,el,options) ->
		binder = @
		for operator in operators
			binder.get(model,operator.property)

class Enable extends Template
	keys: [ "enable" ]

	bind: (operators,model,controller,el,options) ->
		if options.watch
			@bindToModel([operator],model,controller,el,options,"update["+operator.property+"]") for operator in operators
		else
			@bindToModel(operators,model,controller,el,options,"change")

		@update(operators,model,controller,el,options)

	update: (operators,model,controller,el,options) ->
		operator = operators.filter((e) -> e.name is "enable")[0]
		result = @get(model,operator.property)

		if result
			el.removeAttr("disabled")
		else
			el.attr("disabled","disabled")

class Visible extends Template
	keys: [ "visible" ]

	bind: (operators,model,controller,el,options) ->
		if options.watch
			@bindToModel([operator],model,controller,el,options,"update["+operator.property+"]") for operator in operators
		else
			@bindToModel(operators,model,controller,el,options,"update")

		@update(operators,model,controller,el,options)

	update: (operators,model,controller,el,options) ->
		operator = operators.filter((e) -> e.name is "visible")[0]
		result = @get(model,operator.property)

		if result
			el.show()
		else
			el.hide()

class Attribute extends Template
	keys: [ "attr" ]

	bind: (operators,model,controller,el,options) ->
		if options.watch
			for operator in operators
				json = JSON.parse(operator.property)
				for own property of json
					@bindToModel([operator],model,controller,el,options,"update["+json[property]+"]") 
		else
			@bindToModel(operators,model,controller,el,options,"update")

		@update(operators,model,controller,el,options)

	update: (operators,model,controller,el,options) ->
		binder = @
		operator = operators.filter((e) -> e.name is "attr")[0]
		json = JSON.parse(operator.property)
		for own property of json
			value = binder.get(model,json[property])
			if el.attr(property) isnt value
				el.attr(property,value)
				el.trigger("change")
		@

class Checked extends Template
	keys: [ "checked" ]

	bind: (operators,model,controller,el,options) ->
		@bindToElement(operators,model,controller,el,options)

		if options.watch
			@bindToModel([operator],model,controller,el,options,"update["+operator.property+"]") for operator in operators
		else
			@bindToModel(operators,model,controller,el,options,"change")
		
		@update(operators,model,controller,el,options)

	change: (operators,model,controller,el,options) ->
		operator = operators.filter((e) -> e.name is "checked")[0]
		value = @get(model,operator.property)

		if el.attr("type") is "radio"
			if el.length > 1
				current = $($.grep(el, (item) -> $(item).is(":checked"))).val()
				current = true if current == "true"
				current = false if current == "false"
				if value isnt current
					@set(model,operator.property,current,options)
			else
				if el.is(":checked")
					@set(model,operator.property,el.val(),options)
		else
			if value isnt el.is(":checked")
				value = el.is(":checked")
				@set(model,operator.property,value,options)

	update: (operators,model,controller,el,options) ->
		operator = operators.filter((e) -> e.name is "checked")[0]
		result = @get(model,operator.property)
		changed = false
		
		el.each () ->
			e = $(@)
			value = e.val()
			value = true if value == "true"
			value = false if value == "false"

			if e.attr("type") is "radio"
				if result is value
					if not e.is(":checked")
						e.attr("checked", "checked")
						changed = true
						
				else 
					if e.is(":checked")
						e.removeAttr("checked")
						changed = true
			else
				if result 
					if not e.is(":checked")
						e.attr("checked", "checked")
						changed = true
				else
					if e.is(":checked")
						e.removeAttr("checked")
						changed = true
	
		el.trigger("change") if changed

class Hash extends Template
	keys: [ "hash" ]

	@clean: ->
		split = window.location.href.split("#")
		return split[1] ? ""

	@parse: ->
		string = Hash.clean()
		hash = {}
		for item in string.split("&")
			continue if item is ""
			parts = item.split("=")
			key = decodeURIComponent(parts[0])
			value = decodeURIComponent(parts[1])
			continue if not value

			if hash[key]
				hash[key] = [hash[key]]
				hash[key].push(value)
			else
				hash[key] = value

		hash

	enabled: true

	disable: (callback) ->
		if @enabled
			@enabled = false
			try
				do callback
			catch e
				throw e
			finally
				@enabled = true
		else
			do callback

	bind: (operators,model,controller,el,options) ->
		if not @hashbind
			@hashbind = (() ->
				bindings = []

				$(window).bind("hashchange.spine-databind", binder = =>
					hash = Hash.parse()
					binding(hash) for binding in bindings
				)

				controller.bind("destroy-bindings", unbinder = (record) =>
					$(window).unbind("hashchange.spine-databind", binder)
					controller.unbind("destroy-bindings", unbinder)
				)

				(operators,model,controller,el,options) ->
					bindings.push((hash) => @change(operators,model,controller,el,options,hash))
			)()

		@hashbind(operators,model,controller,el,options)

		if options.watch
			@bindToModel([operator],model,controller,el,options,"update["+operator.property+"]") for operator in operators
		else
			@bindToModel(operators,model,controller,el,options,"change")

		hash = Hash.parse()
		@change(operators,model,controller,el,options,hash)

	update: (operators,model,controller,el,options,hash) ->
		return if not @enabled

		hash = Hash.parse()

		for operator in operators
			value = @get(model,operator.property)
			if value
				hash[operator.target] = value
			else
				delete hash[operator.target]

		string = $.param(hash).replace(/%5B%5D/g,"") # Replacing [] with blank, this could be controversial
		if string isnt Hash.clean()
			window.location.hash = string
			$(window).trigger("hashchange")
		@

	change: (operators,model,controller,el,options,hash) ->
		@disable => @set(model,operator.property,hash[operator.target]) for operator in operators

class Cookie extends Template
	keys: [ "cookie" ]

	@get: (sKey) ->
		regex = new RegExp("(?:^|.*;\\s*)" + escape(sKey).replace(/[\-\.\+\*]/g, "\\$&") + "\\s*\\=\\s*((?:[^;](?!;))*[^;]?).*")
		return unescape(document.cookie.replace(regex, "$1")) if regex.test(document.cookie)

	@set: (sKey, sValue, vEnd, sPath, sDomain, bSecure) ->
		return if not sKey or /^(?:expires|max\-age|path|domain|secure)$/i.test(sKey)
		sExpires = ""
		if vEnd?
			switch vEnd.constructor
				when Number
					sExpires = if vEnd is Infinity then "; expires=Tue, 19 Jan 2038 03:14:07 GMT" else "; max-age=" + vEnd
				when String
					sExpires = "; expires=" + vEnd
				when Date
					sExpires = "; expires=" + vEnd.toGMTString()

		document.cookie = escape(sKey) + "=" + escape(sValue) + sExpires + (if sDomain then "; domain=" + sDomain else "") + (if sPath then "; path=" + sPath else "") + (if bSecure then "; secure" else "")

	bind: (operators,model,controller,el,options) ->
		@change(operators,model,controller,el,options)

		if options.watch
			@bindToModel([operator],model,controller,el,options,"update["+operator.property+"]") for operator in operators
		else
			@bindToModel(operators,model,controller,el,options,"change")

	update: (operators,model,controller,el,options) ->
		for operator in operators
			value = @get(model,operator.property)
			Cookie.set(operator.target,value) if value and value isnt "undefined"

	change: (operators,model,controller,el,options) ->
		for operator in operators
			value = Cookie.get(operator.target)
			@set(model,operator.property,value,options)


DataBind =
	binders: [ 
		new Update()
		new Options()
		new Click()
		new Enable()
		new Visible()
		new Attribute()
		new Checked()
		new Hash()
		new Cookie()
	]

	refreshBindings: (model) ->
		model = this.model if not model
		return if not model

		controller = this
		controller.destroyBindings()

		splitter = /(\w+)(\\[.*])? (.*)/

		options = 
			save: if model.watchEnabled then false else true
			watch: if model.watchEnabled then true else false

		$.extend(options, controller.bindingOptions)

		findBinder = (key) ->
			for binder in controller.binders
				if binder.keys.indexOf(key) >= 0
					return binder
			
			return null

		addElement = (elements,info,property) ->
			binder = findBinder(info.name)
			if binder is null then return

			matching = elements.filter((e)->e.el[0] is info.element[0] and e.binder is binder)
			if matching.length is 0
				element = 
					el: info.element
					binder: binder
					operators: []

				elements.push(element)
			else
				element = matching[0]

			element.operators.push({
				name: info.name
				parameters: info.parameters
				property: property
				target: info.target
			})

		parse = (key) ->
			match = key.match(splitter)
			if match isnt null
				name = match[1]
				parameters = match[2]
				target = match[3]
			else
				name = key
				target = ""

			if target is ""
				selector = controller.el
			else
				selector = controller.el.find(target)

			return {
				name: name
				parameters: parameters
				element: selector
				target: target
			}

		bindToModel = (element) ->
			operators = element.operators
			el = element.el

			element.binder.bind(operators,model,controller,el,options)
			controller.bind "release", ->
				element.binder.unbind(operators,model,controller,el,options)

		trim = (s) ->
			s.replace(/^\s+|\s+$/g,"")

		bindingElements = (elements) ->
			(property) ->
				elements.filter (element) ->
					element.operators.some (item) ->
						item.property is property
				.map (result) ->
					result.el[0]

		elements = []

		for key of @bindings
			if @bindings.hasOwnProperty(key)
				property = @bindings[key]
				info = parse(key)
				addElement(elements,info,property)
		
		@el.find("*[data-bind]").each () ->
			e = $(this)
			databind = e.data("bind").split(",")
			attributes = databind.map (item) ->
				fullString = trim(item)
				match = fullString.match(/(\w+):(.*)/)
				name = match[1]
				value = trim(match[2])

				return {
					name: name
					value: value,
					element: e
				}
			
			for info in attributes
				binder = findBinder(info.name)
				addElement(elements,info,info.value)

		for element in elements
			bindToModel(element)

		@bindingElements = bindingElements(elements)

		@

	destroyBindings: ->
		@trigger("destroy-bindings")

DataBind.activators = [ "refreshBindings" ] if Spine.Activator

Controller.DataBind = {}
Controller.DataBind.Template = Template

@Spine.DataBind = DataBind