(function(){

//
// "Array Extras", iff not already provided by this JavaScript environment
//	(compatibility code from mozilla.org --- except that I use a local reference to Array.prototype)
//

var A=Array.prototype, S=String.prototype;

// https://developer.mozilla.org/en/Core_JavaScript_1.5_Reference/Objects/Array/indexOf#Compatibility
if (!A.indexOf)
{
  A.indexOf = function(elt /*, from*/)
  {
    var len = this.length;

    var from = Number(arguments[1]) || 0;
    from = (from < 0)
         ? Math.ceil(from)
         : Math.floor(from);
    if (from < 0)
      from += len;

    for (; from < len; from++)
    {
      if (from in this &&
          this[from] === elt)
        return from;
    }
    return -1;
  };
}

// https://developer.mozilla.org/en/Core_JavaScript_1.5_Reference/Global_Objects/Array/lastIndexOf#Compatibility
if (!A.lastIndexOf)
{
  A.lastIndexOf = function(elt /*, from*/)
  {
    var len = this.length;

    var from = Number(arguments[1]);
    if (isNaN(from))
    {
      from = len - 1;
    }
    else
    {
      from = (from < 0)
           ? Math.ceil(from)
           : Math.floor(from);
      if (from < 0)
        from += len;
      else if (from >= len)
        from = len - 1;
    }

    for (; from > -1; from--)
    {
      if (from in this &&
          this[from] === elt)
        return from;
    }
    return -1;
  };
}

// https://developer.mozilla.org/en/Core_JavaScript_1.5_Reference/Global_Objects/Array/every#Compatibility
if (!A.every)
{
  A.every = function(fun /*, thisp*/)
  {
    var len = this.length;
    if (typeof fun != "function")
      throw new TypeError();

    var thisp = arguments[1];
    for (var i = 0; i < len; i++)
    {
      if (i in this &&
          !fun.call(thisp, this[i], i, this))
        return false;
    }

    return true;
  };
}

// https://developer.mozilla.org/en/Core_JavaScript_1.5_Reference/Global_Objects/Array/filter#Compatibility
if (!A.filter)
{
  A.filter = function(fun /*, thisp*/)
  {
    var len = this.length;
    if (typeof fun != "function")
      throw new TypeError();

    var res = new Array();
    var thisp = arguments[1];
    for (var i = 0; i < len; i++)
    {
      if (i in this)
      {
        var val = this[i]; // in case fun mutates this
        if (fun.call(thisp, val, i, this))
          res.push(val);
      }
    }

    return res;
  };
}

// https://developer.mozilla.org/en/Core_JavaScript_1.5_Reference/Global_Objects/Array/forEach#Compatibility
if (!A.forEach)
{
  A.forEach = function(fun /*, thisp*/)
  {
    var len = this.length;
    if (typeof fun != "function")
      throw new TypeError();

    var thisp = arguments[1];
    for (var i = 0; i < len; i++)
    {
      if (i in this)
        fun.call(thisp, this[i], i, this);
    }
  };
}

// https://developer.mozilla.org/en/Core_JavaScript_1.5_Reference/Global_Objects/Array/map#Compatibility
if (!A.map)
{
  A.map = function(fun /*, thisp*/)
  {
    var len = this.length;
    if (typeof fun != "function")
      throw new TypeError();

    var res = new Array(len);
    var thisp = arguments[1];
    for (var i = 0; i < len; i++)
    {
      if (i in this)
        res[i] = fun.call(thisp, this[i], i, this);
    }

    return res;
  };
}

// https://developer.mozilla.org/en/Core_JavaScript_1.5_Reference/Global_Objects/Array/some#Compatibility
if (!A.some)
{
  A.some = function(fun /*, thisp*/)
  {
    var len = this.length;
    if (typeof fun != "function")
      throw new TypeError();

    var thisp = arguments[1];
    for (var i = 0; i < len; i++)
    {
      if (i in this &&
          fun.call(thisp, this[i], i, this))
        return true;
    }

    return false;
  };
}

// https://developer.mozilla.org/en/Core_JavaScript_1.5_Reference/Objects/Array/reduce#Compatibility
if (!A.reduce)
{
  A.reduce = function(fun /*, initial*/)
  {
    var len = this.length;
    if (typeof fun != "function")
      throw new TypeError();

    // no value to return if no initial value and an empty array
    if (len == 0 && arguments.length == 1)
      throw new TypeError();

    var i = 0;
    if (arguments.length >= 2)
    {
      var rv = arguments[1];
    }
    else
    {
      do
      {
        if (i in this)
        {
          rv = this[i++];
          break;
        }

        // if array contains no values, no initial value to return
        if (++i >= len)
          throw new TypeError();
      }
      while (true);
    }

    for (; i < len; i++)
    {
      if (i in this)
        rv = fun.call(null, rv, this[i], i, this);
    }

    return rv;
  };
}

// https://developer.mozilla.org/en/Core_JavaScript_1.5_Reference/Objects/Array/reduceRight#Compatibility
if (!A.reduceRight)
{
  A.reduceRight = function(fun /*, initial*/)
  {
    var len = this.length;
    if (typeof fun != "function")
      throw new TypeError();

    // no value to return if no initial value, empty array
    if (len == 0 && arguments.length == 1)
      throw new TypeError();

    var i = len - 1;
    if (arguments.length >= 2)
    {
      var rv = arguments[1];
    }
    else
    {
      do
      {
        if (i in this)
        {
          rv = this[i--];
          break;
        }

        // if array contains no values, no initial value to return
        if (--i < 0)
          throw new TypeError();
      }
      while (true);
    }

    for (; i >= 0; i--)
    {
      if (i in this)
        rv = fun.call(null, rv, this[i], i, this);
    }

    return rv;
  };
}



//
// String methods from JavaScript 1.8.1, iff not already provided by this JavaScript environment
//	(our code, because mozilla.org provided none)
//

if (!S.trim)
{
  var trim_regexp=/^\s+|\s+$/g;
  S.trim = function()
  {
    return this.replace(trim_regexp, '');
  };
}

if (!S.trimLeft)
{
  var trimLeft_regexp=/^\s+/;
  S.trimLeft = function()
  {
    return this.replace(trimLeft_regexp, '');
  };
}

if (!S.trimRight)
{
  var trimRight_regexp=/\s+$/;
  S.trimLeft = function()
  {
    return this.replace(trimRight_regexp, '');
  };
}



//
// Array/String "Generics", iff not already provided by this JavaScript environment
//	(our code, because mozilla.org provided none)
//


function make_generic( name ){
	var fn;
	name in this || typeof(fn=this.prototype[name])!=='function' || (this[name]=function( o ){
		return fn.apply(o, A.slice.call(arguments, 1));
	});
}

// We would prefer _not_ to know method names, but to iterate directly over the
// prototype.  Unfortunately,
//
//	for ( var name in /*Array|String*/.prototype )
//
// is unreliable, perhaps because of the native implementation(s).

[
	'concat',
	'every',
	'filter',
	'forEach',
	'indexOf',
	'join',
	'lastIndexOf',
	'map',
	'pop',
	'push',
	'reduce',
	'reduceRight',
	'reverse',
	'shift',
	'slice',
	'some',
	'sort',
	'splice',
	'unshift'
].forEach(make_generic, Array);

[
	'charAt',
	'charCodeAt',
	'concat',
	'indexOf',
	'lastIndexOf',
	'match',
	'replace',
	'search',
	'slice',
	'split',
	'substr',
	'substring',
	'toLowerCase',
	'toUpperCase',
	'trim',
	'trimLeft',
	'trimRight'
].forEach(make_generic, String);

})();
