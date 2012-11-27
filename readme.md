Spine.DataBind
==============

[Knockout](http://knockoutjs.com/) style data-binding for [Spine](http://spinejs.com/).

Full sample with bindings in `data-bind` attributes
---------------------------------------------------

```html
<p>First name: <input name="firstName" /></p>
<p>Last name: <input name="lastName" /></p>
<h2>Hello, <span id="fullName"> </span>!</h2>
```

```javascript 
var PersonCollection = Spine.Model.setup("Person", [ 
  "firstName", 
  "lastName" 
]);

PersonCollection.include({
    fullName: function() {
        return this.firstName + " " + this.lastName;
    }
});

var PersonController = Spine.Controller.create({
    bindings: {
        "value input[name=firstName]": "firstName",
        "value input[name=lastName]": "lastName",
        "text #fullName": "fullName"
    },

    init: function() {
        this.initializeBindings(this.model);
    }
});

PersonController.include(DataBind);

var Person = PersonCollection.create({ firstName: "", lastName: "" });
var Controller = PersonController.init({ el: 'body', model: Person });
```

Full sample with bindings in controller `bindings` property
-----------------------------------------------------------

```html
<div>You've clicked <span id="clicks">&nbsp;</span> times</div>

<button id="clicker">Click me</button>

<div id="reset">
    That's too many clicks! Please stop before you wear out your fingers.
    <button id="resetter">Reset clicks</button>
</div>
```

```javascript 
var ClickCollection = Spine.Model.setup("Click", [ 
    "numberOfClicks" 
]);

ClickCollection.include({
    hasClickedTooManyTimes: function() {
        return this.numberOfClicks >= 3;
    },
    canClick: function() {
        return !this.hasClickedTooManyTimes();
    }
});

var ClickController = Spine.Controller.create({
    events: {
        "click #clicker": "registerClick",
        "click #resetter": "resetClicks"   
    },

    proxied: [ "registerClick" ],

    bindings: {
        "text #clicks": "numberOfClicks",
        "enable #clicker": "canClick",
        "visible #reset": "hasClickedTooManyTimes"
    },

    init: function() {
        this.initializeBindings(this.model);
    },

    registerClick: function() {
        this.model.updateAttribute("numberOfClicks", this.model.numberOfClicks+1);
    },

    resetClicks: function() {
        this.model.updateAttribute("numberOfClicks", 0)
    }
});

ClickController.include(Spine.DataBind);

var Clicker = ClickCollection.create({ numberOfClicks: 0 });
var Controller = ClickController.init({ el: 'body', model:Clicker });
```

[More examples](http://nathanpalmer.github.com/spine.databind/).

Bindings
--------

Bindings can be in the controller's `bindings` property or in markup in a `data-bind` attribute.

The general syntax in markup is:

    binding-type: value-expression 

The general syntax in a controller `bindings` property is:

```javascript
bindings: {}
	"binding-type jquery-selector": "value-expression"
}
```

where `binding-type` is one of:

<table>
	<tr><th>binding type</th><th>element type(s)</th><th></th>
	<tr>
		<th>text</th>
		<td>`td`, etc.</td>
		<td>Model value will go in element's `text` property</td>
	</tr>
	<tr>
		<th>value</th>
		<td>`input`</td>
		<td>Model value will be bound to the element's `value` property.</td>
	</tr>
	<tr>
		<th>checked</th>
		<td>`input`</td>
		<td>The `checked` property of the element will be bound with the model value.</td>
	</tr>
	<tr>
		<th>options</th>
		<td>`select`</td>
		<td>The `option` children of the element will be bound with the model values.</td>
	</tr>
	<tr>
		<th>enabled</th>
		<td>`button`, `input`, etc.</td>
		<td>The `enabled` property of the element will be bound with the model value.</td>
	</tr>
	<tr>
		<th>visible</th>
		<td>Any</td>
		<td>The `visible` property of the element will be bound with the model value.</td>
	</tr>
</table>

The `value-expression` is usually a model property, but it can also be a function. If you bind to a function then the function will be called with the input (etc.) value as the first argument when the input changes, but with an undefined first argument when the input needs to be updated. Also, if you bind to a function, then you may need to explicitly refresh the bindings in the controller with the `refreshBindings` method:

```javascript
this.refreshBindings(this.model);
```