// javascript:$('commentControlBox').innerHTML = Dumper(displaymode)
var DumperIndent = 1;
var DumperIndentText = " ";
var DumperNewline = "\n";
var DumperObject = null; // Keeps track of the root object passed in
var DumperMaxDepth = -1; // Max depth that Dumper will traverse in object
var DumperIgnoreStandardObjects = true; // Ignore top-level objects like window, document
var DumperProperties = null; // Holds properties of top-level object to traverse - others are igonred
var DumperTagProperties = new Object(); // Holds properties to traverse for certain HTML tags
function DumperGetArgs(a,index) {
	var args = new Array();
	// This is kind of ugly, but I don't want to use js1.2 functions, just in case...
	for (var i=index; i<a.length; i++) {
		args[args.length] = a[i];
	}
	return args;
}
function DumperPopup(o) {
	var w = window.open("about:blank");
	w.document.open();
	w.document.writeln("<HTML><BODY><PRE>");
	w.document.writeln(Dumper(o,DumperGetArgs(arguments,1)));
	w.document.writeln("</PRE></BODY></HTML>");
	w.document.close();
}
function DumperAlert(o) {
	alert(Dumper(o,DumperGetArgs(arguments,1)));
}
function DumperWrite(o) {
	var argumentsIndex = 1;
	var d = document;
	if (arguments.length>1 && arguments[1]==window.document) {
		d = arguments[1];
		argumentsIndex = 2;
	}
	var temp = DumperIndentText;
	var args = DumperGetArgs(arguments,argumentsIndex)
	DumperIndentText = "&nbsp;";
	d.write(Dumper(o,args));
	DumperIndentText = temp;
}
function DumperPad(len) {
	var ret = "";
	for (var i=0; i<len; i++) {
		ret += DumperIndentText;
	}
	return ret;
}
function Dumper(o) {
	var level = 1;
	var indentLevel = DumperIndent;
	var ret = "";
	if (arguments.length>1 && typeof(arguments[1])=="number") {
		level = arguments[1];
		indentLevel = arguments[2];
		if (o == DumperObject) {
			return "[original object]";
		}
	}
	else {
		DumperObject = o;
		// If a list of properties are passed in
		if (arguments.length>1) {
			var list = arguments;
			var listIndex = 1;
			if (typeof(arguments[1])=="object") {
				list = arguments[1];
				listIndex = 0;
			}
			for (var i=listIndex; i<list.length; i++) {
				if (DumperProperties == null) { DumperProperties = new Object(); }
				DumperProperties[list[i]]=1;
			}
		}
	}
	if (DumperMaxDepth != -1 && level > DumperMaxDepth) {
		return "...";
	}
	if (DumperIgnoreStandardObjects) {
		if (o==window || o==window.document) {
			return "[Ignored Object]";
		}
	}
	// NULL
	if (o==null) {
		ret = "[null]";
		return ret;
	}
	// FUNCTION
	if (typeof(o)=="function") {
		ret = "[function]";
		return ret;
	} 
	// BOOLEAN
	if (typeof(o)=="boolean") {
		ret = (o)?"true":"false";
		return ret;
	} 
	// STRING
	if (typeof(o)=="string") {
		ret = "'" + o + "'";
		return ret;
	} 
	// NUMBER	
	if (typeof(o)=="number") {
		ret = o;
		return ret;
	}
	if (typeof(o)=="object") {
		if (typeof(o.length)=="number" ) {
			// ARRAY
			ret = "[";
			for (var i=0; i<o.length;i++) {
				if (i>0) {
					ret += "," + DumperNewline + DumperPad(indentLevel);
				}
				else {
					ret += DumperNewline + DumperPad(indentLevel);
				}
				ret += Dumper(o[i],level+1,indentLevel-0+DumperIndent);
			}
			if (i > 0) {
				ret += DumperNewline + DumperPad(indentLevel-DumperIndent);
			}
			ret += "]";
			return ret;
		}
		else {
			// OBJECT
			ret = "{";
			var count = 0;
			for (i in o) {
				if (o==DumperObject && DumperProperties!=null && DumperProperties[i]!=1) {
					// do nothing with this node
				}
				else {
					if (typeof(o[i]) != "unknown") {
						var processAttribute = true;
						// Check if this is a tag object, and if so, if we have to limit properties to look at
						if (typeof(o.tagName)!="undefined") {
							if (typeof(DumperTagProperties[o.tagName])!="undefined") {
								processAttribute = false;
								for (var p=0; p<DumperTagProperties[o.tagName].length; p++) {
									if (DumperTagProperties[o.tagName][p]==i) {
										processAttribute = true;
										break;
									}
								}
							}
						}
						if (processAttribute) {
							if (count++>0) {
								ret += "," + DumperNewline + DumperPad(indentLevel);
							}
							else {
								ret += DumperNewline + DumperPad(indentLevel);
							}
							ret += "'" + i + "' => " + Dumper(o[i],level+1,indentLevel-0+i.length+6+DumperIndent);
						}
					}
				}
			}
			if (count > 0) {
				ret += DumperNewline + DumperPad(indentLevel-DumperIndent);
			}
			ret += "}";
			return ret;
		}
	}
}
