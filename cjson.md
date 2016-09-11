## 通用的方法
### cjson数创建的时候cJSON_CreateObject等通过调用cJSON_New_Item()创建一个空的cjson,
设置其类型，并没有放置数据。
 ```
cJSON *cJSON_CreateObject(void)
{
    cJSON *item = cJSON_New_Item();
    if (item)
		item->type = cJSON_Object;
    return item;
}
//创建一个新的空节点
static cJSON *cJSON_New_Item(void)
{
    cJSON *node = (cJSON *) cJSON_malloc(sizeof(cJSON));
    if (node)
		memset(node, 0, sizeof(cJSON));
    return node;
}
```

## 删除数据
### 递归删除CJson根节点
```
//删除一个json对象，从根开始删除，存在子节点，在子节点处递归，删除本节点可能的内存空间，然后向后遍历
void cJSON_Delete(cJSON * c)
{
	cJSON *next;

	while (c) {
		next = c->next;
		//如果不是引用类型且有子节点则递归删除子节点
		if (!(c->type & cJSON_IsReference) && c->child)
			cJSON_Delete(c->child);
		//如果不是引用类型且有字符串指针，则释放该空间
		if (!(c->type & cJSON_IsReference) && c->valuestring)
			cJSON_free(c->valuestring);
		//如果不是常量类型，且存在key值，释放该空间
		if (!(c->type & cJSON_StringIsConst) && c->string)
			cJSON_free(c->string);
		//释放节点c自己的内存空间
		cJSON_free(c);
		c = next;
	}
}
```
### 删除指定节点
从数组或者cjson树中删除一个节点，首先要找到该节点的位置，使该节点脱离cjson
树，然后进行删除。
该方法在object和array类型中有实现
### 数据的解析
数据解析的调用关系
![](http://ww2.sinaimg.cn/mw690/bf84af6djw1f7mcpszaizj20do0eiwi3.jpg)
把一个字符串解析为cjson树，通过解析符号，调用相应的类型函数创建cjson树，相当于一个自动机。
```
/* Default options for cJSON_Parse */
cJSON *cJSON_Parse(const char *value)
{
	return cJSON_ParseWithOpts(value, 0, 0);
}
cJSON *cJSON_ParseWithOpts(const char *value,
			   const char **return_parse_end,
			   int require_null_terminated)
{
	const char *end = 0;
	cJSON *c = cJSON_New_Item();

	ep = 0;
	if (!c)
		return 0;	/* memory fail */

	end = parse_value(c, skip(value));
	//解析失败，及时释放内存
	if (!end) {
		cJSON_Delete(c);
		return 0;
	}

	/* parse failure. ep is set. */
	/* if we require null-terminated JSON without appended garbage, skip and then check for a null terminator */
	//跳过空的字符串
	if (require_null_terminated) {
		end = skip(end);
		if (*end) {
			cJSON_Delete(c);
			//设置出错的字符串，待验证
			ep = end;
			return 0;
		}
	}
	//需要返回终止的位置字符串
	if (return_parse_end)
		*return_parse_end = end;
	return c;
}
```
数据解析关键函数parse_value的实现过程 

![](http://ww3.sinaimg.cn/mw690/bf84af6djw1f7mav32r3sg20gm07qgli.gif)
```
static const char *parse_value(cJSON * item, const char *value)
{
	if (!value)
		return 0;	/* Fail on null. */
	if (!strncmp(value, "null", 4)) {
		item->type = cJSON_NULL;
		return value + 4;
	}
	if (!strncmp(value, "false", 5)) {
		item->type = cJSON_False;
		return value + 5;
	}
	if (!strncmp(value, "true", 4)) {
		item->type = cJSON_True;
		item->valueint = 1;
		return value + 4;
	}
	if (*value == '\"') {
		return parse_string(item, value);
	}
	if (*value == '-' || (*value >= '0' && *value <= '9')) {
		return parse_number(item, value);
	}
	if (*value == '[') {
		return parse_array(item, value);
	}
	if (*value == '{') {
		return parse_object(item, value);
	}

	ep = value;
	return 0;		/* failure. */
}
```
数据解析的辅助函数，跳过字符串中的空格
```
static const char *skip(const char *in)
{
	while (in && *in && (unsigned char) *in <= 32)
		in++;
	return in;
}
```
### cjson树打印
![](http://ww2.sinaimg.cn/mw690/bf84af6djw1f7pda5oe1bj20jo11vq7l.jpg7)
item为打印节点的信息，depth为打印深度，根据节点的类型不同调用不同类型的打印函数
```
char *cJSON_Print(cJSON * item)
{
	return print_value(item, 0, 1, 0);
}

char *cJSON_PrintUnformatted(cJSON * item)
{
	return print_value(item, 0, 0, 0);
}

char *cJSON_PrintBuffered(cJSON * item, int prebuffer, int fmt)
{
	printbuffer p;

	p.buffer = (char *) cJSON_malloc(prebuffer);
	p.length = prebuffer;
	p.offset = 0;
	return print_value(item, 0, fmt, &p);
	return p.buffer;
}

static char *print_value(cJSON * item, int depth, int fmt, printbuffer * p)
{
	char *out = 0;

	if (!item)
		return 0;
	if (p) {
		switch ((item->type) & 255) {
		case cJSON_NULL:{
				out = ensure(p, 5);
				if (out)
					strcpy(out, "null");
				break;
			}
		case cJSON_False:{
				out = ensure(p, 6);
				if (out)
					strcpy(out, "false");
				break;
			}
		case cJSON_True:{
				out = ensure(p, 5);
				if (out)
					strcpy(out, "true");
				break;
			}
		case cJSON_Number:
			out = print_number(item, p);
			break;
		case cJSON_String:
			out = print_string(item, p);
			break;
		case cJSON_Array:
			out = print_array(item, depth, fmt, p);
			break;
		case cJSON_Object:
			out = print_object(item, depth, fmt, p);
			break;
		}
	} else {
		switch ((item->type) & 255) {
		case cJSON_NULL:
			out = cJSON_strdup("null");
			break;
		case cJSON_False:
			out = cJSON_strdup("false");
			break;
		case cJSON_True:
			out = cJSON_strdup("true");
			break;
		case cJSON_Number:
			out = print_number(item, 0);
			break;
		case cJSON_String:
			out = print_string(item, 0);
			break;
		case cJSON_Array:
			out = print_array(item, depth, fmt, 0);
			break;
		case cJSON_Object:
			out = print_object(item, depth, fmt, 0);
			break;
		}
	}
	return out;
}
```
#### 打印辅助函数
```
//申请一段新的内存空间,复制传入的字符串
static char *cJSON_strdup(const char *str)
{
	size_t len;
	char *copy;

	len = strlen(str) + 1;
	if (!(copy = (char *) cJSON_malloc(len)))
		return 0;
	memcpy(copy, str, len);
	return copy;
}
//length表示buffer最大的容量，offset表示当前的容量
typedef struct {
	char *buffer;
	int length;
	int offset;
} printbuffer;

//确保缓冲区有足够的空间，如果有直接定位到可用空间返回，如果没有则申请新的空间定位可用空间返回
static char *ensure(printbuffer * p, int needed)
{
	char *newbuffer;
	int newsize;

	if (!p || !p->buffer)
		return 0;
	needed += p->offset;
	if (needed <= p->length)
		return p->buffer + p->offset;

	newsize = pow2gt(needed);
	newbuffer = (char *) cJSON_malloc(newsize);
	if (!newbuffer) {
		cJSON_free(p->buffer);
		p->length = 0, p->buffer = 0;
		return 0;
	}
	if (newbuffer)
		memcpy(newbuffer, p->buffer, p->length);
	cJSON_free(p->buffer);
	p->length = newsize;
	p->buffer = newbuffer;
	return newbuffer + p->offset;
}
```


## number类型

### 1、创建number类型的cjson
```
cJSON *cJSON_CreateNumber(double num)
{
	cJSON *item = cJSON_New_Item();

	if (item) {
		item->type = cJSON_Number;
		item->valuedouble = num;
		item->valueint = (int) num;
	}
	return item;
}
```
### 2、解析number
![](http://ww2.sinaimg.cn/mw690/bf84af6djw1f7mav1yhqdg20gm07egll.gif)
```
static const char *parse_number(cJSON * item, const char *num)
{
	double n = 0, sign = 1, scale = 0;
	int subscale = 0, signsubscale = 1;     
	if (*num == '-')
		sign = -1, num++;	/* Has sign? */
    //跳过数字开头中没有意义的0  
	if (*num == '0')
		num++;		/* is zero */
	if (*num >= '1' && *num <= '9')
		do
			n = (n * 10.0) + (*num++ - '0');
		while (*num >= '0' && *num <= '9');	/* Number? */
	if (*num == '.' && num[1] >= '0' && num[1] <= '9') {
		num++;
		do
			n = (n * 10.0) + (*num++ - '0'), scale--;
		while (*num >= '0' && *num <= '9');
	}			/* Fractional part? */
	if (*num == 'e' || *num == 'E') {	/* Exponent? */
		num++;
		if (*num == '+')
			num++;
		else if (*num == '-')
			signsubscale = -1, num++;	/* With sign? */
		while (*num >= '0' && *num <= '9')
			subscale = (subscale * 10) + (*num++ - '0');	/* Number? */
	}
//构造出最终的数值
	n = sign * n * pow(10.0, (scale + subscale * signsubscale));	/* number = +/- number.fraction * 10^+/- exponent */
	//无论是整数还是浮点型都会在int,double两个字段都存放
	item->valuedouble = n;
	item->valueint = (int) n;
	item->type = cJSON_Number;
	return num;
}
```
### 打印数字信息
```
//打印数字,0单独判断，之后判断是否是整数，最后为浮点数。
static char *print_number(cJSON * item, printbuffer * p)
{
	char *str = 0;
	double d = item->valuedouble;

	if (d == 0) {

		if (p)
			str = ensure(p, 2);
		else
			str = (char *) cJSON_malloc(2);	/* special case for 0. */
		if (str)
			strcpy(str, "0");
	} else if (fabs(((double) item->valueint) - d) <= DBL_EPSILON
		   && d <= INT_MAX && d >= INT_MIN) {
		if (p)
			str = ensure(p, 21);
		else
			str = (char *) cJSON_malloc(21);	/* 2^64+1 can be represented in 21 chars. */
		if (str)
			sprintf(str, "%d", item->valueint);
	} else {
		if (p)
			str = ensure(p, 64);
		else
			str = (char *) cJSON_malloc(64);	/* This is a nice tradeoff. */
		if (str) {
			if (fabs(floor(d) - d) <= DBL_EPSILON
			    && fabs(d) < 1.0e60)
				sprintf(str, "%.0f", d);
			else if (fabs(d) < 1.0e-6 || fabs(d) > 1.0e9)
				sprintf(str, "%e", d);
			else
				sprintf(str, "%f", d);
		}
	}
	return str;
}
```
## string类型
### 创建类型
创建类型很简单，类似于number类型的创建
### string字符串解析
![](http://ww4.sinaimg.cn/mw690/bf84af6djw1f7mav2sscig20gm0bhmxc.gif)
```
static const char *parse_string(cJSON * item, const char *str)
{
	const char *ptr = str + 1;
	char *ptr2;
	char *out;
	int len = 0;
	unsigned uc, uc2;

	if (*str != '\"') {
		ep = str;
		return 0;
	}
	/* not a string! */
	while (*ptr != '\"' && *ptr && ++len)
		if (*ptr++ == '\\')
			ptr++;	/* Skip escaped quotes. */

	out = (char *) cJSON_malloc(len + 1);	/* This is how long we need for the string, roughly. */
	if (!out)
		return 0;

	ptr = str + 1;
	ptr2 = out;
	while (*ptr != '\"' && *ptr) {
		if (*ptr != '\\')
			*ptr2++ = *ptr++;
		else {
			ptr++;
			switch (*ptr) {
			case 'b':
				*ptr2++ = '\b';
				break;
			case 'f':
				*ptr2++ = '\f';
				break;
			case 'n':
				*ptr2++ = '\n';
				break;
			case 'r':
				*ptr2++ = '\r';
				break;
			case 't':
				*ptr2++ = '\t';
				break;
			case 'u':	/* transcode utf16 to utf8. */
				uc = parse_hex4(ptr + 1);
				ptr += 4;	/* get the unicode char. */

				if ((uc >= 0xDC00 && uc <= 0xDFFF)
				    || uc == 0)
					break;	/* check for invalid.   */

				if (uc >= 0xD800 && uc <= 0xDBFF) {	/* UTF16 surrogate pairs. */
					if (ptr[1] != '\\'
					    || ptr[2] != 'u')
						break;	/* missing second-half of surrogate.    */
					uc2 = parse_hex4(ptr + 3);
					ptr += 6;
					if (uc2 < 0xDC00 || uc2 > 0xDFFF)
						break;	/* invalid second-half of surrogate.    */
					uc = 0x10000 +
					    (((uc & 0x3FF) << 10) |
					     (uc2 & 0x3FF));
				}

				len = 4;
				if (uc < 0x80)
					len = 1;
				else if (uc < 0x800)
					len = 2;
				else if (uc < 0x10000)
					len = 3;
				ptr2 += len;

				switch (len) {
				case 4:
					*--ptr2 = ((uc | 0x80) & 0xBF);
					uc >>= 6;
				case 3:
					*--ptr2 = ((uc | 0x80) & 0xBF);
					uc >>= 6;
				case 2:
					*--ptr2 = ((uc | 0x80) & 0xBF);
					uc >>= 6;
				case 1:
					*--ptr2 =
					    (uc | firstByteMark[len]);
				}
				ptr2 += len;
				break;
			default:
				*ptr2++ = *ptr;
				break;
			}
			ptr++;
		}
	}
	*ptr2 = 0;
	if (*ptr == '\"')
		ptr++;
	item->valuestring = out;
	item->type = cJSON_String;
	return ptr;
}
### 打印字符串信息
/* Invote print_string_ptr (which is useful) on an item. */
static char *print_string(cJSON * item, printbuffer * p)
{
	return print_string_ptr(item->valuestring, p);
}
/* Render the cstring provided to an escaped version that can be printed. */
static char *print_string_ptr(const char *str, printbuffer * p)
{
	const char *ptr;
	char *ptr2, *out;
	int len = 0, flag = 0;
	unsigned char token;

	for (ptr = str; *ptr; ptr++)
		flag |= ((*ptr > 0 && *ptr < 32) || (*ptr == '\"')
			 || (*ptr == '\\')) ? 1 : 0;
	if (!flag) {
		len = ptr - str;
		if (p)
			out = ensure(p, len + 3);
		else
			out = (char *) cJSON_malloc(len + 3);
		if (!out)
			return 0;
		ptr2 = out;
		*ptr2++ = '\"';
		strcpy(ptr2, str);
		ptr2[len] = '\"';
		ptr2[len + 1] = 0;
		return out;
	}

	if (!str) {
		if (p)
			out = ensure(p, 3);
		else
			out = (char *) cJSON_malloc(3);
		if (!out)
			return 0;
		strcpy(out, "\"\"");
		return out;
	}
	ptr = str;
	while ((token = *ptr) && ++len) {
		if (strchr("\"\\\b\f\n\r\t", token))
			len++;
		else if (token < 32)
			len += 5;
		ptr++;
	}

	if (p)
		out = ensure(p, len + 3);
	else
		out = (char *) cJSON_malloc(len + 3);
	if (!out)
		return 0;

	ptr2 = out;
	ptr = str;
	*ptr2++ = '\"';
	while (*ptr) {
		if ((unsigned char) *ptr > 31 && *ptr != '\"'
		    && *ptr != '\\')
			*ptr2++ = *ptr++;
		else {
			*ptr2++ = '\\';
			switch (token = *ptr++) {
			case '\\':
				*ptr2++ = '\\';
				break;
			case '\"':
				*ptr2++ = '\"';
				break;
			case '\b':
				*ptr2++ = 'b';
				break;
			case '\f':
				*ptr2++ = 'f';
				break;
			case '\n':
				*ptr2++ = 'n';
				break;
			case '\r':
				*ptr2++ = 'r';
				break;
			case '\t':
				*ptr2++ = 't';
				break;
			default:
				sprintf(ptr2, "u%04x", token);
				ptr2 += 5;
				break;	/* escape and print */
			}
		}
	}
	*ptr2++ = '\"';
	*ptr2++ = 0;
	return out;
}

```
## object类型
### 创建类型
object类型的节点没有包含数据，是个类型节点
```
cJSON *cJSON_CreateObject(void)
{
    cJSON *item = cJSON_New_Item();
    if (item)
		item->type = cJSON_Object;
    return item;
}
```
### 类型解析
![](http://ww2.sinaimg.cn/mw690/bf84af6djw1f7mav2brwgg20gm035a9w.gif)
```
static const char *parse_object(cJSON * item, const char *value)
{
	cJSON *child;

	if (*value != '{') {
		ep = value;
		return 0;
	}
	/* not an object! */
	item->type = cJSON_Object;
	value = skip(value + 1);
	if (*value == '}')
		return value + 1;	/* empty array. */

	item->child = child = cJSON_New_Item();
	if (!item->child)
		return 0;
	value = skip(parse_string(child, skip(value)));
	if (!value)
		return 0;
	child->string = child->valuestring;
	child->valuestring = 0;
	if (*value != ':') {
		ep = value;
		return 0;
	}			/* fail! */
	value = skip(parse_value(child, skip(value + 1)));	/* skip any spacing, get the value. */
	if (!value)
		return 0;

	while (*value == ',') {
		cJSON *new_item;

		if (!(new_item = cJSON_New_Item()))
			return 0;	/* memory fail */
		child->next = new_item;
		new_item->prev = child;
		child = new_item;
		value = skip(parse_string(child, skip(value + 1)));
		if (!value)
			return 0;
		child->string = child->valuestring;
		child->valuestring = 0;
		if (*value != ':') {
			ep = value;
			return 0;
		}		/* fail! */
		value = skip(parse_value(child, skip(value + 1)));	/* skip any spacing, get the value. */
		if (!value)
			return 0;
	}

	if (*value == '}')
		return value + 1;	/* end of array */
	ep = value;
	return 0;		/* malformed. */
}
```
### 查找object
```
cJSON *cJSON_GetObjectItem(cJSON * object, const char *string)
{
	cJSON *c = object->child;

	while (c && cJSON_strcasecmp(c->string, string))
		c = c->next;
	return c;
}
```
### 替换object
在cjson树中找到需要替换的object，代码同cJSON_GetObjectItem，之后调用
cJSON_ReplaceItemInArray进行替换
```
void cJSON_ReplaceItemInObject(cJSON * object, const char *string,
			       cJSON * newitem)
{
	int i = 0;
	cJSON *c = object->child;

	while (c && cJSON_strcasecmp(c->string, string))
		i++, c = c->next;
	if (c) {
		newitem->string = cJSON_strdup(string);
		cJSON_ReplaceItemInArray(object, i, newitem);
	}
}
```
### 添加object
```
void cJSON_AddItemToObject(cJSON * object, const char *string,
			   cJSON * item)
{
	if (!item)
		return;
	if (item->string)
		cJSON_free(item->string);
	item->string = cJSON_strdup(string);
	cJSON_AddItemToArray(object, item);
}
void cJSON_AddItemToObjectCS(cJSON * object, const char *string,
			     cJSON * item)
{
	if (!item)
		return;
	if (!(item->type & cJSON_StringIsConst) && item->string)
		cJSON_free(item->string);
	item->string = (char *) string;
	item->type |= cJSON_StringIsConst;
	cJSON_AddItemToArray(object, item);
}

void cJSON_AddItemReferenceToObject(cJSON * object, const char *string,
				    cJSON * item)
{
	cJSON_AddItemToObject(object, string, create_reference(item));
}
```
### 删除object
删除一个object先找到该object的位置，然后使该节点脱离cjson树，之后进行删除
```
void cJSON_DeleteItemFromObject(cJSON * object, const char *string)
{
	cJSON_Delete(cJSON_DetachItemFromObject(object, string));
}
cJSON *cJSON_DetachItemFromObject(cJSON * object, const char *string)
{
	int i = 0;
	cJSON *c = object->child;

	while (c && cJSON_strcasecmp(c->string, string))
		i++, c = c->next;
	if (c)
		return cJSON_DetachItemFromArray(object, i);
	return 0;
}
```
## array类型
### array类型创建
```
cJSON *cJSON_CreateArray(void)
{
	cJSON *item = cJSON_New_Item();

	if (item)
		item->type = cJSON_Array;
	return item;
}
```
上面的创建过程只创建了一个类型，没有实际的数据，数组中可以存放数字，字符串等
cjson提供了如下的封装
```
cJSON *cJSON_CreateIntArray(const int *numbers, int count)
{
	int i;
	cJSON *n = 0, *p = 0, *a = cJSON_CreateArray();

	for (i = 0; a && i < count; i++) {
		n = cJSON_CreateNumber(numbers[i]);
		if (!i)
			a->child = n;
		else
			suffix_object(p, n);
		p = n;
	}
	return a;
}
```
### 解析array
从一个字符串构建array
```
static const char *parse_array(cJSON * item, const char *value)
{
	cJSON *child;

	if (*value != '[') {
		ep = value;
		return 0;
	}
	/* not an array! */
	item->type = cJSON_Array;
	value = skip(value + 1);
	if (*value == ']')
		return value + 1;	/* empty array. */

	item->child = child = cJSON_New_Item();
	if (!item->child)
		return 0;	/* memory fail */
	value = skip(parse_value(child, skip(value)));	/* skip any spacing, get the value. */
	if (!value)
		return 0;

	while (*value == ',') {
		cJSON *new_item;

		if (!(new_item = cJSON_New_Item()))
			return 0;	/* memory fail */
		child->next = new_item;
		new_item->prev = child;
		child = new_item;
		value = skip(parse_value(child, skip(value + 1)));
		if (!value)
			return 0;	/* memory fail */
	}

	if (*value == ']')
		return value + 1;	/* end of array */
	ep = value;
	return 0;		/* malformed. */
}
```
### 返回array的数组长度
```
int cJSON_GetArraySize(cJSON * array)
{
	cJSON *c = array->child;
	int i = 0;

	while (c)
		i++, c = c->next;
	return i;
}
```
### array中返回指定位置的cjson节点
```
cJSON *cJSON_GetArrayItem(cJSON * array, int item)
{
	cJSON *c = array->child;

	while (c && item > 0)
		item--, c = c->next;
	return c;
}
```
### 向array中添加数据
```
//向array添加新的对象，添加在最后，如果是第一个则是节点头的子节点，否则为前一个节点的后继节点
void cJSON_AddItemToArray(cJSON * array, cJSON * item)
{
	cJSON *c = array->child;

	if (!item)
		return;
	if (!c) {
		array->child = item;
	} else {
		while (c && c->next)
			c = c->next;
		suffix_object(c, item);
	}
}
void cJSON_AddItemReferenceToArray(cJSON * array, cJSON * item)
{
	cJSON_AddItemToArray(array, create_reference(item));
}
```
### 向array中插入数据
```
void cJSON_InsertItemInArray(cJSON * array, int which, cJSON * newitem)
{
	cJSON *c = array->child;

	while (c && which > 0)
		c = c->next, which--;
    //如果指定的位置大于当前数组的长度，直接在数组最后添加即可
	if (!c) {
		cJSON_AddItemToArray(array, newitem);
		return;
	}
    //找到指定的位置进行插入
	newitem->next = c;
	newitem->prev = c->prev;
	c->prev = newitem;
	if (c == array->child)
		array->child = newitem;
	else
		newitem->prev->next = newitem;
}
```
### 对array中的数据进行替换
```
void cJSON_ReplaceItemInArray(cJSON * array, int which, cJSON * newitem)
{
	cJSON *c = array->child;

	while (c && which > 0)
		c = c->next, which--;
//找不到指定位置进行返回
	if (!c)  
		return;
//找到指定位置进行替换
	newitem->next = c->next;
	newitem->prev = c->prev;
	if (newitem->next)
		newitem->next->prev = newitem;
	if (c == array->child)
		array->child = newitem;
	else
		newitem->prev->next = newitem;
	c->next = c->prev = 0;
//释放旧的节点
	cJSON_Delete(c);
}
```
### 从array中删除数据
从array中删除数据也要先取消挂载之后删除。同object数据一样
```
void cJSON_DeleteItemFromArray(cJSON * array, int which)
{
	cJSON_Delete(cJSON_DetachItemFromArray(array, which));
}
//从array中取消挂载一个结点，注意节点是第一个节点的情况
cJSON *cJSON_DetachItemFromArray(cJSON * array, int which)
{
	cJSON *c = array->child;

	while (c && which > 0)
		c = c->next, which--;
	if (!c)
		return 0;
	if (c->prev)
		c->prev->next = c->next;
	if (c->next)
		c->next->prev = c->prev;
	if (c == array->child)
		array->child = c->next;
	c->prev = c->next = 0;
	return c;
}

```
