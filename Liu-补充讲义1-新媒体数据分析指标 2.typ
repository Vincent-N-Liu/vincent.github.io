// Simple numbering for non-book documents
#let equation-numbering = "(1)"
#let callout-numbering = "1"
#let subfloat-numbering(n-super, subfloat-idx) = {
  numbering("1a", n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Simple numbering for non-book documents (no heading inheritance)
#let theorem-inherited-levels = 0

// Theorem numbering format (can be overridden by extensions for appendix support)
// This function returns the numbering pattern to use
#let theorem-numbering(loc) = "1.1"

// Default theorem render function
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  body
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  place(
    top,
    float: true,
    scope: "parent",
    clearance: 4mm,
    block(below: 1em, width: 100%)[

      #if title != none {
        align(center, block(inset: 2em)[
          #set par(leading: heading-line-height) if heading-line-height != none
          #set text(font: heading-family) if heading-family != none
          #set text(weight: heading-weight)
          #set text(style: heading-style) if heading-style != "normal"
          #set text(fill: heading-color) if heading-color != black

          #text(size: title-size)[#title #if thanks != none {
            footnote(thanks, numbering: "*")
            counter(footnote).update(n => n - 1)
          }]
          #(if subtitle != none {
            parbreak()
            text(size: subtitle-size)[#subtitle]
          })
        ])
      }

      #if authors != none and authors != () {
        let count = authors.len()
        let ncols = calc.min(count, 3)
        grid(
          columns: (1fr,) * ncols,
          row-gutter: 1.5em,
          ..authors.map(author =>
              align(center)[
                #author.name \
                #author.affiliation \
                #author.email
              ]
          )
        )
      }

      #if date != none {
        align(center)[#block(inset: 1em)[
          #date
        ]]
      }

      #if abstract != none {
        block(inset: 2em)[
        #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
        ]
      }
    ]
  )

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#import "@preview/fontawesome:0.5.0": *
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "a4",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)

#show: doc => article(
  title: [Liu-补充讲义1-新媒体数据分析指标],
  authors: (
    ( name: [刘念夏],
      affiliation: [],
      email: [] ),
    ),
  date: [19 March 2026],
  font: ("PingFang TC",),
  fontsize: 11pt,
  heading-family: ("PingFang TC",),
  sectionnumbering: "1.1.1",
  toc: true,
  toc_title: [Table of contents],
  toc_depth: 3,
  doc,
)

#heading(level: 1, numbering: none)[AARRR分析模型]
<aarrr分析模型>
#figure([
#box(image("AARRR模型.png"))
], caption: figure.caption(
position: bottom, 
[
AARRR MODEL
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)


= 拉新指标
<拉新指标>
是衡量新媒体广告投放效果的重要指标，主要包括CPM（Cost Per Mill）、CPC（Cost Per Click）和CPA（Cost Per Action）。这些指标帮助广告主评估广告投放的效率和效果，从而优化广告策略，提高投资回报率。

== CPM（Cost Per Mill）
<cpmcost-per-mill>
指每千次曝光的成本，它是衡量广告投放效率的重要指标，反映了广告主为每千次广告曝光所支付的费用。CPM越低，表示广告投放效率越高，广告主能够以更低的成本获得更多的曝光机会。

=== 计算公式：
<计算公式>
$ upright("CPM") = (upright("总花费成本") / upright("总曝光次数")) times 1 \, 000 $

=== 计算示例：
<计算示例>
假设一个广告活动的总花费成本为5000元，总曝光次数为200000次，那么CPM的计算如下：

$ upright("CPM") & = frac(5 \, 000, 200 \, 000) times 1 \, 000\
 & = 0.025 times 1 \, 000\
 & = 25 $

因此，该广告活动的CPM为25元，意味着广告主每获得1000次曝光需要支付25元的费用。

== CPC（Cost Per Click）
<cpccost-per-click>
指每次点击的成本，是衡量广告投放效果的重要指标，反映了广告主为每次用户点击所支付的费用。CPC越低，表示广告投放效率越高，广告主能够以更低的成本吸引更多的用户点击。

=== 计算公式：
<计算公式-1>
$ upright("CPC") = (upright("总花费成本") / upright("总点击次数")) $

=== 计算示例：
<计算示例-1>
假设你投放了一个网页广告，想吸引人进某个网站，总花费 3,000元，该网页广告总点击次数150次。那么CPC的计算如下：

$ upright("CPC") & = frac(3 \, 000, 150)\
 & = 20 $

每吸引1个潜在用户点进网站，需要支付20元。

== CPA（Cost Per Action）
<cpacost-per-action>
指每次行动的成本， 计算逻辑是：总广告花费除以实际达成的行动（转换）次数。是衡量广告投放效果的重要指标，反映了广告主为每次用户完成特定行动所支付的费用。CPA越低，表示广告投放效率越高，广告主能够以更低的成本促使更多的用户完成特定行动。「行动」的定义由你決定，常見的包括：完成報名、购买產品、下载 App、填寫谘询表單等。

=== 计算公式：
<计算公式-2>
$ upright("CPA") = (upright("总花费成本") / upright("总转化次数")) $

=== 计算示例：
<计算示例-2>
假设你举办了一場「线上讲座」，並透过广告导流报名： 总广告花费： 10,000 元，总点击数 (CPC 階段)： 500 次， 最终完成报名人数： 20 。

那么CPA的计算如下：

$ upright("CPA") & = frac(10 \, 000, 20)\
 & = 50 $

每促成1个用户完成报名，需要支付50元的费用。这个CPA值可以帮助你评估广告投放的效果，并决定是否需要调整广告策略以降低CPA，提高转化率。

== 三大指標比較表 (CPM / CPC / CPA)
<三大指標比較表-cpm-cpc-cpa>
#table(
  columns: (20.27%, 20.27%, 28.38%, 31.08%),
  align: (auto,auto,auto,auto,),
  table.header([指标], [英文], [核心关注点], [范例],),
  table.hline(),
  [CPM], [Cost Per Mille], [品牌曝光 (被看見)], [花 1,000 元让 10,000 人看到],
  [CPC], [Cost Per Click], [网站流量 (点進來)], [花 1,000 元換 100 个人進站。],
  [CPA], [Cost Per Action], [最終转换 (留资料/買東西）], [花 1,000 元換 2 个人下單。],
)
#block[
#callout(
body: 
[
CPA 最重要

- 衡量真正的投资报酬率 (ROI)： 点击再多，如果没人买单也是徒劳。CPA 直接告诉你获取一个客户的代价。

- 预算控制： 如果你知道一个学员的报名费是 3,000 元，而你的 CPA 是 500 元，那你就能清楚算出利润空间。

- 优化转换率 (CVR)： 如果 CPC 很低（很多人进站）但 CPA 很高（没人买），就代表你的网页内容或产品定价出了问题

]
, 
title: 
[
Important
]
, 
background_color: 
rgb("#f7dddc")
, 
icon_color: 
rgb("#CC1914")
, 
icon: 
fa-exclamation()
, 
body_background_color: 
white
)
]
= 活跃指标
<活跃指标>
== 日活跃用户数（DAU, Daily Active User)
<日活跃用户数dau-daily-active-user>
表示在一天24小时内至少访问过一次网站或应用程序的#strong[不重複用戶（Unique Users）(独立用户)]數量。不管同一個用户在一天內進出網站多少次，DAU 都只會計算為 1。与此对应的，还有#strong[周活跃用户数]\(WAU, Weekely Active User)与#strong[月活跃用户数]\(MAU, Monthly Active User)。

== 用户黏着度（Stick Rate）
<用户黏着度stick-rate>
指用户在一定时间内的活跃程度，通常通过DAU（每日活跃用户数）与MAU（月活跃用户数）的比率来衡量。这个指标反映了用户对网站或应用程序的忠诚度和使用频率。用户黏着度越高，表示用户更频繁地使用该平台，说明平台具有较强的吸引力和用户粘性。

$ upright("用戶黏著度(Stick Rate)") = (upright("DAU") / upright("MAU")) times 100 % $

=== 舉例：
<舉例>
如果某老师开设一门线上课程，有 100 名學生选修 (MAU = 100)。每天固定會上線看進度的學生有 20 名 (DAU = 20)，则黏著度： $20 \/ 100 = 20 %$。

== PV(Page View)
<pvpage-view>
指页面浏览量，网页被「加载」或「刷新」的总次数。只要页面被读取一次，PV 就会加 1。衡量网站或应用程序的访问量。#underline[#strong[#emph[每当用户访问一个页面时，PV就会增加一次]]]。PV是评估网站流量和用户兴趣的重要指标，通常用于分析网站的受欢迎程度和内容的吸引力。

计算逻辑： 不管是谁看的，只要有开启网页的动作就计算。 同一个使用者反覆刷新页面，PV 会不断累积。

== UV(Unique Visitor)
<uvunique-visitor>
指独立访客数(唯一页面浏览量)，在同一个工作阶段内，特定网页被浏览的「次数」。它排除了重复浏览，以「人（精确来说是浏览器/Cookie）」为单位。衡量在一定时间内访问网站或应用程序的独立用户数量。#underline[#strong[#emph[每个独立用户只会被计算一次，无论他们访问了多少次]]]。UV是评估网站受众规模和用户覆盖范围的重要指标，通常用于分析网站的用户基础和市场渗透率。

计算逻辑： 同一个使用者在一次访问中，不管看几次同个页面，只算 1 次。能更准确地反映出「有多少人」看过这个内容。

== 比较(PV;UV)
<比较pvuv>
假设有一位学生进入某老师的课程网站，发生了以下行为：

1.进入 #NormalTok("首页 (Home)");

2.点击进入 #NormalTok("课程大纲 (Syllabus)");

3.按「重新整理」刷新 #NormalTok("课程大纲");

4.回到 #NormalTok("首页");

5.再次点进 #NormalTok("课程大纲");

統計結果如下：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([页面], [PV], [UV],),
  table.hline(),
  [首页], [2], [1],
  [课程大纲], [3], [1],
  [#strong[总计]], [#strong[5]], [#strong[2]],
)
这两个数字的「差距」能告诉你很多关于网页内容的信息：

- PV 远高于 UV：

---可能是好现象： 代表内容非常吸引人，使用者反覆回来查看（例如：参考资料、工具页面）。

---也可能是坏现象： 可能代表网页加载有问题、信息太复杂，导致使用者必须不断重新整理或来回跳转才能看清楚。

- PV 与 UV接近：

---代表使用者通常「看完就走」，没有回头再看的动力。
