enum ValueType {
	TNull;
	TInt;
	TFloat;
	TBool;
	TObject;
	TFunction;
	TClass( c : Class<Dynamic> );
	TEnum( e : Enum<Dynamic> );
	TUnknown;
}

@:coreApi
class Type {

	static var allTypes(get,never) : hl.types.NativeBytesMap;
	static inline function get_allTypes() : hl.types.NativeBytesMap return untyped $allTypes();

	@:keep static function init() : Void {
		untyped $allTypes(new hl.types.NativeBytesMap());
	}

	@:keep static function register( b : hl.types.Bytes, t : hl.types.BaseType ) : Void {
		allTypes.set(b, t);
	}

	public static function getClass<T>( o : T ) : Class<T> {
		var t = hl.types.Type.getDynamic(o);
		if( t.kind == HObj )
			return t.getGlobal();
		return null;
	}

	public static function getEnum( o : EnumValue ) : Enum<Dynamic> {
		var t = hl.types.Type.getDynamic(o);
		if( t.kind == HEnum )
			return t.getGlobal();
		return null;
	}

	public static function getSuperClass( c : Class<Dynamic> ) : Class<Dynamic> @:privateAccess {
		var c : hl.types.BaseType.Class = cast c;
		var t = c.__type__.getSuper();
		return t == hl.types.Type.get((null : Void)) ? null : t.getGlobal();
	}

	public static function getClassName( c : Class<Dynamic> ) : String {
		var c : hl.types.BaseType.Class = cast c;
		return c.__name__;
	}

	public static function getEnumName( e : Enum<Dynamic> ) : String {
		var e : hl.types.BaseType.Enum = cast e;
		return e.__ename__;
	}

	public static function resolveClass( name : String ) : Class<Dynamic> {
		var t : hl.types.BaseType = allTypes.get(@:privateAccess name.bytes);
		if( t == null || !Std.is(t, hl.types.BaseType.Class) )
			return null;
		return cast t;
	}

	public static function resolveEnum( name : String ) : Enum<Dynamic> {
		var t : hl.types.BaseType = allTypes.get(@:privateAccess name.bytes);
		if( t == null || !Std.is(t, hl.types.BaseType.Enum) )
			return null;
		return cast t;
	}

	public static function createInstance<T>( cl : Class<T>, args : Array<Dynamic> ) : T {
		var c : hl.types.BaseType.Class = cast cl;
		var t = c.__type__;
		if( t == hl.types.Type.get((null : hl.types.ArrayBase.ArrayAccess)) )
			return cast new Array<Dynamic>();
		var o = t.allocObject();
		if( c.__constructor__ != null ) Reflect.callMethod(o, c.__constructor__, args);
		return o;
	}

	public static function createEmptyInstance<T>( cl : Class<T> ) : T {
		var c : hl.types.BaseType.Class = cast cl;
		return c.__type__.allocObject();
	}

	public static function createEnum<T>( e : Enum<T>, constr : String, ?params : Array<Dynamic> ) : T {
		var en : hl.types.BaseType.Enum = cast e;
		var idx : Null<Int> = en.__emap__.get(@:privateAccess constr.bytes);
		if( idx == null ) throw "Unknown enum constructor " + en.__ename__ +"." + constr;
		return createEnumIndex(e,idx,params);
	}

	public static function createEnumIndex<T>( e : Enum<T>, index : Int, ?params : Array<Dynamic> ) : T {
		var e : hl.types.BaseType.Enum = cast e;
		if( index < 0 || index >= e.__constructs__.length ) throw "Invalid enum index " + e.__ename__ +"." + index;
		if( params == null || params.length == 0 ) {
			var v = index >= e.__evalues__.length ? null : e.__evalues__[index];
			if( v == null ) throw "Constructor " + e.__ename__ +"." + e.__constructs__[index] + " takes parameters";
			return v;
		}
		var a : hl.types.ArrayDyn = cast params;
		var aobj = Std.instance(@:privateAccess a.array, hl.types.ArrayObj);
		var narr;
		if( aobj == null ) {
			narr = new hl.types.NativeArray<Dynamic>(a.length);
			for( i in 0...a.length )
				narr[i] = @:privateAccess a.array.getDyn(i);
		} else {
			narr = @:privateAccess aobj.array;
		}
		var v = @:privateAccess e.__type__.allocEnum(index, narr);
		if( v == null ) throw "Constructor " + e.__ename__ +"." + e.__constructs__[index] + " does not takes " + narr.length + " parameters";
		return v;
	}

	public static function getInstanceFields( c : Class<Dynamic> ) : Array<String> @:privateAccess {
		var c : hl.types.BaseType.Class = cast c;
		var fields = c.__type__.getInstanceFields();
		return [for( f in fields ) String.fromUCS2(f)];
	}

	public static function getClassFields( c : Class<Dynamic> ) : Array<String> {
		var c : hl.types.BaseType.Class = cast c;
		var fields = @:privateAccess Reflect.getObjectFields(c, false);
		var fields = [for( f in fields ) @:privateAccess String.fromUCS2(f)];
		fields.remove("__constructor__");
		fields.remove("__meta__");
		fields.remove("__name__");
		fields.remove("__type__");
		fields.remove("__implementedBy__");
		return fields;
	}

	public static function getEnumConstructs( e : Enum<Dynamic> ) : Array<String> {
		var e : hl.types.BaseType.Enum = cast e;
		return e.__constructs__.copy();
	}

	public static function typeof( v : Dynamic ) : ValueType {
		var t = hl.types.Type.getDynamic(v);
		switch( t.kind ) {
		case HVoid:
			return TNull;
		case HI8, HI16, HI32:
			return TInt;
		case HF32, HF64:
			return TFloat;
		case HBool:
			return TBool;
		case HDynObj:
			return TObject;
		case HObj:
			var c : Dynamic = Type.getClass(v);
			if( c == Class || c == null )
				return TObject;
			return TClass(c);
		case HEnum:
			return TEnum(Type.getEnum(v));
		case HFun:
			return TFunction;
		case HVirtual:
			var v = hl.types.Api.getVirtualValue(v);
			if( v == null )
				return TObject;
			return typeof(v);
		default:
			return TUnknown;
		}
	}

	@:hlNative("std","type_enum_eq")
	public static function enumEq<T:EnumValue>( a : T, b : T ) : Bool {
		return false;
	}

	public static function enumConstructor( e : EnumValue ) : String {
		var en : hl.types.BaseType.Enum = cast getEnum(e);
		return en.__constructs__[Type.enumIndex(e)];
	}

	@:hlNative("std","enum_parameters")
	static function _enumParameters( e : EnumValue ) : hl.types.NativeArray<Dynamic> {
		return null;
	}

	public static function enumParameters( e : EnumValue ) : Array<Dynamic> {
		var arr = _enumParameters(e);
		return cast hl.types.ArrayObj.alloc(arr);
	}

	@:extern public inline static function enumIndex( e : EnumValue ) : Int {
		return untyped $enumIndex(e);
	}

	public static function allEnums<T>( e : Enum<T> ) : Array<T> {
		var en : hl.types.BaseType.Enum = cast e;
		var out = [];
		for( i in 0...en.__evalues__.length ) {
			var v = en.__evalues__[i];
			if( v != null ) out.push(v);
		}
		return out;
	}

}