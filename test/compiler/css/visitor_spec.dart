library angular2.test.compiler.css.visitor_spec;

import "package:angular2/testing_internal.dart"
    show ddescribe, describe, it, iit, xit, expect, beforeEach, afterEach;
import "package:angular2/src/facade/lang.dart"
    show NumberWrapper, StringWrapper, isPresent;
import "package:angular2/src/facade/exceptions.dart" show BaseException;
import "package:angular2/src/compiler/css/parser.dart"
    show
        CssToken,
        CssParser,
        CssParseError,
        BlockType,
        CssAST,
        CssSelectorRuleAST,
        CssKeyframeRuleAST,
        CssKeyframeDefinitionAST,
        CssBlockDefinitionRuleAST,
        CssMediaQueryRuleAST,
        CssBlockRuleAST,
        CssInlineRuleAST,
        CssStyleValueAST,
        CssSelectorAST,
        CssDefinitionAST,
        CssStyleSheetAST,
        CssRuleAST,
        CssBlockAST,
        CssASTVisitor,
        CssUnknownTokenListAST;
import "package:angular2/src/compiler/css/lexer.dart" show CssLexer;

_assertTokens(tokens, valuesArr) {
  for (var i = 0; i < tokens.length; i++) {
    expect(tokens[i].strValue == valuesArr[i]);
  }
}

class MyVisitor implements CssASTVisitor {
  Map<String, List<dynamic>> captures = {};
  _capture(method, ast, context) {
    this.captures[method] =
        isPresent(this.captures[method]) ? this.captures[method] : [];
    this.captures[method].add([ast, context]);
  }

  MyVisitor(CssStyleSheetAST ast, [dynamic context]) {
    ast.visit(this, context);
  }
  void visitCssValue(ast, [dynamic context]) {
    this._capture("visitCssValue", ast, context);
  }

  void visitInlineCssRule(ast, [dynamic context]) {
    this._capture("visitInlineCssRule", ast, context);
  }

  void visitCssKeyframeRule(CssKeyframeRuleAST ast, [dynamic context]) {
    this._capture("visitCssKeyframeRule", ast, context);
    ast.block.visit(this, context);
  }

  void visitCssKeyframeDefinition(CssKeyframeDefinitionAST ast,
      [dynamic context]) {
    this._capture("visitCssKeyframeDefinition", ast, context);
    ast.block.visit(this, context);
  }

  void visitCssMediaQueryRule(CssMediaQueryRuleAST ast, [dynamic context]) {
    this._capture("visitCssMediaQueryRule", ast, context);
    ast.block.visit(this, context);
  }

  void visitCssSelectorRule(CssSelectorRuleAST ast, [dynamic context]) {
    this._capture("visitCssSelectorRule", ast, context);
    ast.selectors.forEach((CssSelectorAST selAST) {
      selAST.visit(this, context);
    });
    ast.block.visit(this, context);
  }

  void visitCssSelector(CssSelectorAST ast, [dynamic context]) {
    this._capture("visitCssSelector", ast, context);
  }

  void visitCssDefinition(CssDefinitionAST ast, [dynamic context]) {
    this._capture("visitCssDefinition", ast, context);
    ast.value.visit(this, context);
  }

  void visitCssBlock(CssBlockAST ast, [dynamic context]) {
    this._capture("visitCssBlock", ast, context);
    ast.entries.forEach((CssAST entryAST) {
      entryAST.visit(this, context);
    });
  }

  void visitCssStyleSheet(CssStyleSheetAST ast, [dynamic context]) {
    this._capture("visitCssStyleSheet", ast, context);
    ast.rules.forEach((CssRuleAST ruleAST) {
      ruleAST.visit(this, context);
    });
  }

  void visitUnkownRule(CssUnknownTokenListAST ast, [dynamic context]) {}
}

main() {
  parse(String cssCode) {
    var lexer = new CssLexer();
    var scanner = lexer.scan(cssCode);
    var parser = new CssParser(scanner, "some-fake-file-name.css");
    var output = parser.parse();
    var errors = output.errors;
    if (errors.length > 0) {
      throw new BaseException(
          errors.map((CssParseError error) => error.msg).toList().join(", "));
    }
    return output.ast;
  }
  describe("CSS parsing and visiting", () {
    var ast;
    var context = {};
    beforeEach(() {
      var cssCode = '''
        .rule1 { prop1: value1 }
        .rule2 { prop2: value2 }

        @media all (max-width: 100px) {
          #id { prop3 :value3; }
        }

        @import url(file.css);

        @keyframes rotate {
          from {
            prop4: value4;
          }
          50%, 100% {
            prop5: value5;
          }
        }
      ''';
      ast = parse(cssCode);
    });
    it("should parse and visit a stylesheet", () {
      var visitor = new MyVisitor(ast, context);
      var captures = visitor.captures["visitCssStyleSheet"];
      expect(captures.length).toEqual(1);
      var capture = captures[0];
      expect(capture[0]).toEqual(ast);
      expect(capture[1]).toEqual(context);
    });
    it("should parse and visit each of the stylesheet selectors", () {
      var visitor = new MyVisitor(ast, context);
      var captures = visitor.captures["visitCssSelectorRule"];
      expect(captures.length).toEqual(3);
      var rule1 = (captures[0][0] as CssSelectorRuleAST);
      expect(rule1).toEqual(ast.rules[0]);
      _assertTokens(rule1.selectors[0].tokens, [".", "rule1"]);
      var rule2 = (captures[1][0] as CssSelectorRuleAST);
      expect(rule2).toEqual(ast.rules[1]);
      _assertTokens(rule2.selectors[0].tokens, [".", "rule2"]);
      var rule3 = captures[2][0];
      expect(rule3)
          .toEqual(((ast.rules[2] as CssMediaQueryRuleAST)).block.entries[0]);
      _assertTokens(rule3.selectors[0].tokens, ["#", "rule3"]);
    });
    it("should parse and visit each of the stylesheet style key/value definitions",
        () {
      var visitor = new MyVisitor(ast, context);
      var captures = visitor.captures["visitCssDefinition"];
      expect(captures.length).toEqual(5);
      var def1 = (captures[0][0] as CssDefinitionAST);
      expect(def1.property.strValue).toEqual("prop1");
      expect(def1.value.tokens[0].strValue).toEqual("value1");
      var def2 = (captures[1][0] as CssDefinitionAST);
      expect(def2.property.strValue).toEqual("prop2");
      expect(def2.value.tokens[0].strValue).toEqual("value2");
      var def3 = (captures[2][0] as CssDefinitionAST);
      expect(def3.property.strValue).toEqual("prop3");
      expect(def3.value.tokens[0].strValue).toEqual("value3");
      var def4 = (captures[3][0] as CssDefinitionAST);
      expect(def4.property.strValue).toEqual("prop4");
      expect(def4.value.tokens[0].strValue).toEqual("value4");
      var def5 = (captures[4][0] as CssDefinitionAST);
      expect(def5.property.strValue).toEqual("prop5");
      expect(def5.value.tokens[0].strValue).toEqual("value5");
    });
    it("should parse and visit the associated media query values", () {
      var visitor = new MyVisitor(ast, context);
      var captures = visitor.captures["visitCssMediaQueryRule"];
      expect(captures.length).toEqual(1);
      var query1 = (captures[0][0] as CssMediaQueryRuleAST);
      _assertTokens(
          query1.query, ["all", "and", "(", "max-width", "100", "px", ")"]);
      expect(query1.block.entries.length).toEqual(1);
    });
    it("should parse and visit the associated \"@inline\" rule values", () {
      var visitor = new MyVisitor(ast, context);
      var captures = visitor.captures["visitInlineCssRule"];
      expect(captures.length).toEqual(1);
      var query1 = (captures[0][0] as CssInlineRuleAST);
      expect(query1.type).toEqual(BlockType.Import);
      _assertTokens(query1.value.tokens, ["url", "(", "file.css", ")"]);
    });
    it("should parse and visit the keyframe blocks", () {
      var visitor = new MyVisitor(ast, context);
      var captures = visitor.captures["visitCssKeyframeRule"];
      expect(captures.length).toEqual(1);
      var keyframe1 = (captures[0][0] as CssKeyframeRuleAST);
      expect(keyframe1.name.strValue).toEqual("rotate");
      expect(keyframe1.block.entries.length).toEqual(2);
    });
    it("should parse and visit the associated keyframe rules", () {
      var visitor = new MyVisitor(ast, context);
      var captures = visitor.captures["visitCssKeyframeDefinition"];
      expect(captures.length).toEqual(2);
      var def1 = (captures[0][0] as CssKeyframeDefinitionAST);
      _assertTokens(def1.steps, ["from"]);
      expect(def1.block.entries.length).toEqual(1);
      var def2 = (captures[1][0] as CssKeyframeDefinitionAST);
      _assertTokens(def2.steps, ["50%", "100%"]);
      expect(def2.block.entries.length).toEqual(1);
    });
  });
}