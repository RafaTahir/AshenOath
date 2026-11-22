import ast, hashlib, io, json, pathlib, re, subprocess, tokenize

ROOT = pathlib.Path(__file__).resolve().parent
CONFIG = json.loads((ROOT/'config.json').read_text(encoding="utf-8-sig"))
FROZEN = pathlib.Path(CONFIG['source_project'])
PREFIX = FROZEN.relative_to(pathlib.Path(CONFIG['source_repo'])).as_posix()
URL = 'https://raw.githubusercontent.com/godotengine/godot/4.6.3-stable/modules/gdscript/gdscript_tokenizer.h'
header = (ROOT/'godot_4_6_3_tokenizer.h').read_text(encoding='utf-8')
block = header.split('enum Type {',1)[1].split('};',1)[0]
names = [line.split('//')[0].strip().rstrip(',') for line in block.splitlines()]
names = [name for name in names if name]
types = {name: number for number,name in enumerate(names)}
keywords = {name.lower(): number for name,number in types.items() if name in [
 'AND','OR','NOT','IF','ELIF','ELSE','FOR','WHILE','BREAK','CONTINUE','PASS','RETURN','MATCH','WHEN',
 'AS','ASSERT','AWAIT','BREAKPOINT','CLASS','CLASS_NAME','ENUM','EXTENDS','FUNC','IS','NAMESPACE',
 'PRELOAD','SELF','SIGNAL','STATIC','SUPER','TRAIT','VAR','YIELD']}
keywords.update({'_':types['UNDERSCORE'],'const':types['TK_CONST'],'in':types['TK_IN'],'void':types['TK_VOID'],
                 'PI':types['CONST_PI'],'TAU':types['CONST_TAU'],'INF':types['CONST_INF'],'NAN':types['CONST_NAN']})
operators = {'<':'LESS','<=':'LESS_EQUAL','>':'GREATER','>=':'GREATER_EQUAL','==':'EQUAL_EQUAL','!=':'BANG_EQUAL',
 '&&':'AMPERSAND_AMPERSAND','||':'PIPE_PIPE','!':'BANG','&':'AMPERSAND','|':'PIPE','~':'TILDE','^':'CARET',
 '<<':'LESS_LESS','>>':'GREATER_GREATER','+':'PLUS','-':'MINUS','*':'STAR','**':'STAR_STAR','/':'SLASH','%':'PERCENT',
 '=':'EQUAL','+=':'PLUS_EQUAL','-=':'MINUS_EQUAL','*=':'STAR_EQUAL','**=':'STAR_STAR_EQUAL','/=':'SLASH_EQUAL',
 '%=':'PERCENT_EQUAL','<<=':'LESS_LESS_EQUAL','>>=':'GREATER_GREATER_EQUAL','&=':'AMPERSAND_EQUAL',
 '|=':'PIPE_EQUAL','^=':'CARET_EQUAL','[':'BRACKET_OPEN',']':'BRACKET_CLOSE','{':'BRACE_OPEN','}':'BRACE_CLOSE',
 '(':'PARENTHESIS_OPEN',')':'PARENTHESIS_CLOSE',',':'COMMA',';':'SEMICOLON','.':'PERIOD','..':'PERIOD_PERIOD',
 '...':'PERIOD_PERIOD_PERIOD',':':'COLON','$':'DOLLAR','->':'FORWARD_ARROW','_':'UNDERSCORE'}

def literal(value):
    # Godot's Variant text preserves physical newlines inside quoted strings.
    value=value.replace('\r','\\r').replace('\n','\\n')
    if value in ['true','false','null']:
        return {'true':True,'false':False,'null':None}[value]
    if value.startswith('&'):
        return ['StringName', ast.literal_eval(value[1:])]
    if value.startswith('^'):
        return ['NodePath', ast.literal_eval(value[1:])]
    return ast.literal_eval(value)

def source_tokens(source):
    raw = list(tokenize.generate_tokens(io.StringIO(source).readline))
    ignored = {tokenize.COMMENT,tokenize.NL,tokenize.NEWLINE,tokenize.INDENT,tokenize.DEDENT,tokenize.ENDMARKER}
    raw = [token for token in raw if token.type not in ignored and not(token.type==tokenize.ERRORTOKEN and token.string.isspace())]
    result=[]
    index=0
    while index<len(raw):
        token=raw[index]
        line=token.start[0]
        word=token.string
        value=''
        if word=='@' and index+1<len(raw) and raw[index+1].type==tokenize.NAME:
            index+=1; kind=types['ANNOTATION']; value=raw[index].string
        elif word in ['&','^'] and index+1<len(raw) and raw[index+1].type==tokenize.STRING:
            index+=1; kind=types['LITERAL']; value=literal(word+raw[index].string)
        elif token.type==tokenize.NAME:
            if word in ['true','false','null']:
                kind=types['LITERAL']; value=literal(word)
            else:
                kind=keywords.get(word,types['IDENTIFIER'])
                value=word if kind==types['IDENTIFIER'] else ''
        elif token.type in [tokenize.STRING,tokenize.NUMBER]:
            kind=types['LITERAL']; value=literal(word)
        elif word==':=':
            result.append([line,types['COLON'],''])
            kind=types['EQUAL']
        else:
            if word not in operators: raise ValueError(('Unsupported source operator',word,line))
            kind=types[operators[word]]
        result.append([line,kind,value]); index+=1
    return result

reports=[]
all_same=True
for entry in json.loads((ROOT/'root/token_decode.json').read_text(encoding="utf-8-sig")):
    relative=entry['path'][:-1]
    source=(FROZEN/relative).read_bytes().decode('utf-8-sig')
    source_lf=source.replace('\r\n','\n')
    original=subprocess.check_output(['git','-C',CONFIG['source_repo'],'show',CONFIG['expected_commit']+':'+PREFIX+'/'+relative]).decode('utf-8-sig')
    original=original.replace('\r\n','\n')
    actual=[]
    for token in json.loads(pathlib.Path(entry['tokens_json']).read_text(encoding="utf-8-sig")):
        value=literal(token['value']) if token['type']==types['LITERAL'] else token['value']
        actual.append([token['line'],token['type'],value])
    expected=source_tokens(source)
    differences=[]
    index=0
    expected_index=0
    folded_unary_numbers=0
    while index<len(actual) or expected_index<len(expected):
        a=actual[index] if index<len(actual) else None
        b=expected[expected_index] if expected_index<len(expected) else None
        # Godot lexically folds signed numeric literals where Python emits a
        # sign token followed by a number; preserve every other token exactly.
        if a and b and a[1]==types['LITERAL'] and type(a[2]) in [int,float] and b[1] in [types['MINUS'],types['PLUS']] and expected_index+1<len(expected):
            n=expected[expected_index+1]
            sign=-1 if b[1]==types['MINUS'] else 1
            if n[1]==types['LITERAL'] and type(n[2]) in [int,float] and a[0]==b[0]==n[0] and a[2]==sign*n[2]:
                expected_index+=1
                b=[b[0],types['LITERAL'],sign*n[2]]
                folded_unary_numbers+=1
        if a!=b:
            differences.append({'token_index':index,'packed':a,'frozen':b})
            if len(differences)==8: break
        index+=1
        expected_index+=1
    indentation_differences=[]
    source_lines=source.splitlines()
    for boundary in entry['line_boundaries']:
        line=source_lines[boundary['line']-1]
        prefix=line[:len(line)-len(line.lstrip(' \t'))]
        expected_column=1+len(prefix.expandtabs(4))
        if boundary['column']!=expected_column:
            indentation_differences.append({'line':boundary['line'],'packed_column':boundary['column'],'frozen_column':expected_column})
    same=not differences and not indentation_differences and source_lf==original
    all_same &= same
    record={'path':relative,'frozen_source_sha256':hashlib.sha256(source.encode()).hexdigest(),
            'frozen_source_sha256_lf':hashlib.sha256(source_lf.encode()).hexdigest(),
            'frozen_matches_expected_commit_lf':source_lf==original,'compiled_sha256':entry['compiled_sha256'],
            'packed_tokens':len(actual),'frozen_lexical_tokens':len(expected),'normalized_unary_numbers':folded_unary_numbers,
            'tokens_match':not differences,'differences':differences,'indentation_boundaries':len(entry['line_boundaries']),
            'indentation_matches':not indentation_differences,'indentation_differences':indentation_differences}
    reports.append(record)
    print(json.dumps(record))
result={'status':'PASS' if all_same else 'FAIL','scope':'Actual decoded root PCK compiled tokens vs complete frozen '+CONFIG['expected_commit']+' source token streams; every token line/type/identifier/literal/operator and statement indentation column',
        'format_reference':URL,'scripts':reports}
(ROOT/'comparison.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
raise SystemExit(0 if all_same else 1)
