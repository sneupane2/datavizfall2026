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

// Margin layout support using marginalia package
#import "@preview/marginalia:0.3.1" as marginalia: note, notefigure, wideblock

// Render footnote as margin note using standard footnote counter
// Used via show rule: #show footnote: it => column-sidenote(it.body)
// The footnote element already steps the counter, so we just display it
#let column-sidenote(body) = {
  context {
    let num = counter(footnote).display("1")
    // Superscript mark in text
    super(num)
    // Content in margin with matching number
    note(
      alignment: "baseline",
      shift: auto,
      counter: none,  // We display our own number from footnote counter
    )[
      #super(num) #body
    ]
  }
}

// Note: Margin citations are now emitted directly from Lua as #note() calls
// with #cite(form: "full") + locator text, preserving citation locators.

// Utility: compute padding for each side based on side parameter
#let side-pad(side, left-amount, right-amount) = {
  let l = if side == "both" or side == "left" or side == "inner" { left-amount } else { 0pt }
  let r = if side == "both" or side == "right" or side == "outer" { right-amount } else { 0pt }
  (left: l, right: r)
}

// body-outset: extends ~15% into margin area
#let column-body-outset(side: "both", body) = context {
  let r = marginalia.get-right()
  let out = 0.15 * (r.sep + r.width)
  pad(..side-pad(side, -out, -out), body)
}

// page-inset: wideblock minus small inset from page boundary
#let column-page-inset(side: "both", body) = context {
  let l = marginalia.get-left()
  let r = marginalia.get-right()
  // Inset is a small fraction of the extension area (wideblock stops at far)
  let left-inset = 0.15 * l.sep
  let right-inset = 0.15 * (r.sep + r.width)
  wideblock(side: side)[#pad(..side-pad(side, left-inset, right-inset), body)]
}

// screen-inset: full width minus `far` distance from edges
#let column-screen-inset(side: "both", body) = context {
  let l = marginalia.get-left()
  let r = marginalia.get-right()
  wideblock(side: side)[#pad(..side-pad(side, l.far, r.far), body)]
}

// screen-inset-shaded: screen-inset with gray background
#let column-screen-inset-shaded(body) = context {
  let l = marginalia.get-left()
  wideblock(side: "both")[
    #block(fill: luma(245), width: 100%, inset: (x: l.far, y: 1em), body)
  ]
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
// Get these values from the YAML and make them typst variables because writing
// out shortcodes all the time is messy
#let header-left = [PMAP]
#let header-right = [Spring]
#let footer-left = [Data]

// The course uses Fira Sans Condensed, but for Reasons, Typst doesn't see it
// and lumps it together with regular Fira Sans (like, if you run `typst fonts`
// in the terminal, the condensed version doesn't appear)
//
// To get the condensed version, you have to set `stretch` to some value:
//
// font: "Fira Sans", stretch: 75%


// H1
#show heading.where(level: 1): it => {
  block(
    width: 100%,
    above: 1.5em,
    below: 0.8em,
    stroke: (bottom: 1pt + luma(170)),
    inset: (bottom: 0.4em),
    [
      #set text(font: "Fira Sans", stretch: 75%, size: 1em)
      #it
    ]
  )
}

// H2
#show heading.where(level: 2): it => {
  set text(font: "Fira Sans", stretch: 75%, size: 0.95em)
  set block(above: 1.5em, below: 0.8em)
  it
}

// H6 - headings in the course details section
#show heading.where(level: 6): it => {
  set text(font: "Fira Sans", stretch: 75%, size: 1.1em)
  set block(below: 0.8em)
  it
}


// Center tables in the .centered-table div
#let centered-table(body) = {
  align(center, body)
}

// ...aaaand center tables in the .schedule-table div too
#let schedule-table(body) = {
  // set text(size: 0.85em)
  set par(justify: false)
  body
}


// 3-column course details section that replicates the Bootstrap grid divs ----
#let grid-col(body) = body

#let course-details(body) = {
  block(
    fill: luma(240),
    inset: 1em,
    above: 2em,
    below: 2em,
    width: 100%,
    {
      set text(size: 0.9em)
      set par(justify: false)
      // Get rid of empty elements
      let cols = body.children.filter(c => c != [ ] and c != [
])
      grid(
        columns: 3,
        gutter: 2em,
        ..cols
      )
    }
  )
}


// Restyle Quarto callout boxes since they're a little too spacy
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    stroke: (
      left: 3pt + icon_color,
      top: 0.5pt + icon_color,
      right: 0.5pt + icon_color,
      bottom: 0.5pt + icon_color
    ),
    radius: 2pt,
    width: 100%,
    [
      #set text(size: 0.9em)
      #set par(leading: 0.65em)
      #block(
        fill: background_color,
        inset: 0.5em,
        width: 100%,
        below: 0pt,
        text(icon_color, weight: "bold")[#icon #title]
      )
      #block(
        fill: body_background_color,
        inset: 0.5em,
        width: 100%,
        body
      )
    ]
  )
}


// Restyle and reformat the title area
#let original-article = article

#let article(
  title: none,
  subtitle: none,
  ..args,
  doc
) = {
  let remaining = args.named()

  set align(left)

  // Title and logo side by side
  if title != none {
    grid(
      columns: (1fr, auto),
      column-gutter: 1em,
      align: (left, right),

      // Left column: title and subtitle
      block(inset: (bottom: 1.5em))[
        #block(
          below: 2em,
          text(font: "Fira Sans", stretch: 75%, size: 2em, weight: "bold")[#title]
        )
        #if subtitle != none {
          block(
            above: 0em,
            text(font: "Fira Sans", stretch: 75%, size: 1.2em, weight: "regular")[#subtitle]
          )
        }
      ],

      // Right column: logo
      align(horizon)[
        #image("files/course-icon.png", width: 1in)
      ]
    )
  }

  original-article(
    title: none,
    subtitle: none,
    ..remaining,
    doc
  )
}

// Running header and footer
#set page(
  header: context {
    if counter(page).get().first() > 1 {
      set text(font: "Barlow", size: 0.8em)
      grid(
        columns: (1fr, 1fr),
        align: (left, right),
        header-left,
        header-right
      )
    }
  },
  footer: context [
    #set text(font: "Barlow", size: 0.8em)
    #grid(
      columns: (1fr, 1fr),
      align: (left, right),
      footer-left,
      counter(page).display("1")
    )
  ]
)

// General global styling stuff
#show par: set par(justify: false)  // This has to come at the end of this file
#set text(hyphenate: false)
#show link: set text(fill: rgb("#E16462"))
// Transform footnotes to sidenotes
#show footnote: it => column-sidenote(it.body)
#show footnote.entry: none
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  // Margins handled by marginalia.setup below
  numbering: "1",
  columns: 1,
)
// Configure marginalia page geometry (functions defined in definitions.typ)
#show: marginalia.setup.with(
  inner: (
    far: 0.649in,
    width: 0.811in,
    sep: 0.325in,
  ),
  outer: (
    far: 0.648in,
    width: 1.620in,
    sep: 0.324in,
  ),
  top: 1.25in,
  bottom: 1.25in,
  book: false,
  clearance: 12pt,
)

#show: doc => article(
  title: [Data Visualization with R],
  subtitle: [PMAP 8551/4551 • Spring 2026],
  font: ("Barlow",),
  fontsize: 10pt,
  heading-family: ("Barlow",),
  toc_title: [Table of contents],
  toc_depth: 3,
  doc,
)
// Add a note to the top of the page about where the full real syllabus lives.
//
// This has to get injected as part of include-before-body and not in
// include-in-header because otherwise this gets placed on an empty A4 page at
// the beginning of the document because of how it interacts with `#set page()`
//
// I wish there was a way to get this note-content from YAML, but alas.

// #let note-content = [*Note*#h(1em)The full version of the course syllabus, schedule, and all course materials is available online at #link("https://governancef25.classes.andrewheiss.com/"). This is only a partially complete static version.]
#let note-content = [*NOTE*#h(1em)The full version of the course syllabus, schedule, and all course
materials is available online at
<https://datavizsp26.classes.andrewheiss.com/>. This is only a partially
complete static version.
]

#place(
  top + left,
  dy: -1in,  // Move this thing into the top margin
  block(
    width: 100%,
    fill: rgb("#FCCE2540"),
    stroke: rgb("#FCCE25"),
    inset: 1em,
    {
      set text(size: 0.85em)
      set par(justify: false)
      note-content
    }
  )
)

#course-details[
#grid-col[
====== Instructor
<instructor>
-  #link("https://www.andrewheiss.com")[Dr.~Andrew Heiss]
-  55 Park Place NE, Room 464
-  aheiss\@gsu.edu
-  #link("https://bsky.app/profile/andrew.heiss.phd")[Bluesky]

]
#grid-col[
====== Course details
<course-details>
-  Any day
-  January 12--May 4, 2026
-  Asynchronous
-  Anywhere

]
#grid-col[
====== Contacting me
<contacting-me>
-  #link("https://scheduler.zoom.us/andrewheiss")[Schedule an appointment]
-  #link("https://discord.com/")[Discord]

]
]
= Course objectives
<course-objectives>
#strong[Data rarely speaks for itself.] On their own, the facts contained in raw data are difficult to understand, and in the absence of beauty and order, it is impossible to understand the truth that the data shows.

In this class, you'll learn how to use industry-standard graphic and data design techniques to create beautiful, understandable visualizations and uncover truth in data.

By the end of this course, you will become (1) literate in data and graphic design principles, and (2) an ethical data communicator, by producing beautiful, powerful, and clear visualizations of your own data. Specifically, you should:

- Understand the principles of data and graphic design
- Evaluate the credibility, ethics, and aesthetics of data visualizations
- Create well-designed data visualizations with appropriate tools
- Share data and graphics in open forums
- Feel comfortable with R
- Be curious and confident in consuming and producing data visualizations

This class will expose you to #link("https://cran.r-project.org/")[R]---one of the most popular, sought-after, and in-demand statistical programming languages. Armed with the foundation of R skills you'll learn in this class, you'll know enough to be able to find how to visualize and analyze any sort of data-based question in the future.

= Important pep talk!
<important-pep-talk>
I #emph[promise] you can succeed in this class.

Learning R can be difficult at first---it's like learning a new language, just like Spanish, French, or Chinese. Hadley Wickham---the chief data scientist at RStudio and the author of some amazing R packages you'll be using like {ggplot2}---#link("https://r-posts.com/advice-to-young-and-old-programmers-a-conversation-with-hadley-wickham/")[made this wise observation]:

#quote(block: true)[
It's easy when you start out programming to get really frustrated and think, "Oh it's me, I'm really stupid," or, "I'm not made out to program." But, that is absolutely not the case. Everyone gets frustrated. I still get frustrated occasionally when writing R code. It's just a natural part of programming. So, it happens to everyone and gets less and less over time. Don't blame yourself. Just take a break, do something fun, and then come back and try again later.
]

Even experienced programmers find themselves bashing their heads against seemingly intractable errors. If you're finding yourself taking way too long hitting your head against a wall and not understanding, take a break, talk to classmates, e-mail me, etc.

#align(center)[#box(image("./files/img/syllabus/hosrt_error_tweet.png", width: 60.0%))]
#figure([
#box(image("./files/img/syllabus/gator_error.jpg"))
], caption: figure.caption(
position: bottom, 
[
Alison Horst: Gator error
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)


= Course materials
<course-materials>
All of the readings and software in this class are #strong[free]. There are free online versions of all the textbooks, R and RStudio are inherently free, and you can use #link("./resource/graphics-editors.qmd")[free vector editing software].

== Books, articles, and other materials
<books-articles-and-other-materials>
We'll rely heavily on these books, which are all available online (#strong[for free!]). I recommend getting the printed versions of these books if you are interested, but it is not required.

- Alberto Cairo, #emph[The Truthful Art: Data, Charts, and Maps for Communication] (Berkeley, California: New Riders, 2016). \$20 used, \$50 new at #link("https://www.amazon.com/Truthful-Art-Data-Charts-Communication/dp/0321934075")[Amazon].

  A #strong[free] eBook version is available through GSU's library through O'Reilly's Higher Education database. The easiest way to access it is to visit a special URL (#link("http://go.oreilly.com/georgia-state-university")), log in with your GSU account, and then search for "The Truthful Art".

- Kieran Healy, #emph[Data Visualization: A Practical Introduction] (Princeton: Princeton University Press, 2018), #link("http://socviz.co/"). #link("http://socviz.co/")[#strong[FREE] online]\; \$20 used, \$40 new at #link("https://www.amazon.com/Data-Visualization-Introduction-Kieran-Healy/dp/0691181624/")[Amazon].

- Claus E. Wilke, #emph[Fundamentals of Data Visualization] (Sebastopol, California: O'Reilly Media, 2018), #link("https://serialmentor.com/dataviz/"). #link("https://clauswilke.com/dataviz/")[#strong[FREE] online]\; \$36 used, \$50 new at #link("https://www.amazon.com/Fundamentals-Data-Visualization-Informative-Compelling/dp/1492031089")[Amazon]. An eBook version is also available through #link("http://go.oreilly.com/georgia-state-university")[the O'Reilly database], but you can just use #link("https://clauswilke.com/dataviz/")[the online version].

There will occasionally be additional articles and videos to read and watch. When this happens, links to these other resources will be included on the content page for that session.

== R and RStudio
<r-and-rstudio>
You will do all of your analysis with the open source (and free!) programming language #link("https://cran.r-project.org/")[R]. You will use #link("https://www.rstudio.com/")[RStudio] as the main program to access R. #strong[Think of R as an engine and RStudio as a car dashboard]---R handles all the calculations produces the actual statistics and graphical output, while RStudio provides a nice interface for running R code.

R is free, but it can sometimes be a pain to install and configure. To make life easier, you can (and should!) use the free #link("http://posit.cloud/")[Posit.cloud] service, which lets you run a full instance of RStudio in your web browser. This means you won't have to install anything on your computer to get started with R! We will have a shared class workspace in Posit.cloud that will let you quickly copy templates for examples, exercises, and mini projects.

Posit.cloud is convenient, but it can be slow and it is not designed to be able to handle larger datasets or more complicated analysis and graphics. You also can't use your own custom fonts with Posit.cloud. Over the course of the semester, you'll probably want to get around to installing R, RStudio, and other R packages on your computer and wean yourself off of Posit.cloud. This isn't 100% necessary, but it's helpful.

You can #link("./resource/install.qmd")[find instructions for installing R, RStudio, and all the tidyverse packages here.]

== Online help
<online-help>
Data science and statistical programming can be difficult. Computers are stupid and little errors in your code can cause hours of headache (even if you've been doing this stuff for years!).

Fortunately there are tons of online resources to help you with this.

=== Class community on Discord
<class-community-on-discord>
We have a class Discord server where anyone in the class can ask questions and anyone can answer. The invitation to the server is on iCollege since that's a password protected place and I want the server to be limited to only students in the class.

#strong[I will monitor Discord regularly and will respond quickly.] (It's one of the rare Discord servers where I actually have notifications enabled!) Ask questions about the readings, exercises, and mini projects. You'll likely have similar questions as your peers, and you'll likely be able to answer other peoples' questions too.

=== Online communities
<online-communities>
If you use Bluesky or Mastodon or Threads or LinkedIn, post R-related questions and content with #NormalTok("#rstats");. The R community is exceptionally generous and helpful.

Searching for help with R on Google can sometimes be tricky because the program name is, um, a single letter. Google is generally smart enough to figure out what you mean when you search for "r scatterplot", but if it does struggle, try searching for "rstats" instead (e.g.~"rstats scatterplot"). Also, since most of your R work will deal with {ggplot2}, it's often easier to just search for that instead of the letter "r" (e.g.~"ggplot scatterplot").

You can also check out the #link("https://community.rstudio.com/")[Posit Community], a forum specifically designed for people using RStudio and the tidyverse (i.e.~you).

= AI, LLMs, BS, and vibe coding
<ai-llms-bs-and-vibe-coding>
I #emph[highly recommend] #strong[not] using ChatGPT or similar large language models (LLMs) in this class.

I am deeply opposed to LLMs for writing.

I am kinda opposed to LLMs for code, but I am deeply opposed to them for beginners at code.

By definition, LLMs and other AI tools cannot produce truth (or even lies). They generate #link("https://doi.org/10.1007/s10676-024-09775-5")[bullshit]#footnote[I'm a super straight-laced Mormon and, like, never ever swear or curse, but in this case, the word has a formal philosophical meaning (Harry G. Frankfurt, #emph[On Bullshit] (Princeton University Press, 2005)), so it doesn't count :)]---a formal philosophical term that refers to text or speech that has no regard for truth.#footnote[Michael Townsen Hicks, James Humphries, and Joe Slater, “ChatGPT Is Bullshit,” #emph[Ethics and Information Technology] 26, no. 2 (2024): 38, #link("https://doi.org/10.1007/s10676-024-09775-5")\; Frankfurt, #emph[On Bullshit].]

#link("./resource/ai-bs.qmd")[Please read this] to better understand how LLMs circumvent the writing and learning process.

#strong[Do not replace the important work of writing with AI BS slop.] The point of writing is to help crystalize your thinking. Chugging out words that make it look like you read and understood the content will not help you learn. Chugging out code that you hope works is #link("https://www.npr.org/2025/05/30/nx-s1-5413387/vibe-coding-ai-software-development")[vibe coding] and it will not help you learn.

A key theme of the class is the search for truth. Generating useless content will not help with that.

In your session check-ins and assignments, I want to see good engagement with the readings. I want to see your thinking process. I want to see you make connections between the readings. I want to see your personal insights. I don't want to see a bunch of words that look like a human wrote them. That's not useful for future-you. That's not useful for me. That's a waste of time.

I will not spend time trying to guess if your assignments are AI-generated.#footnote[There are tools that purport to be able to identify the percentage of a given text that is AI, but they do not work and result in all sorts of false positives.] If you do turn in AI-produced content, I won't automatically give you a zero, with one exception: #emph[if your work contains fake data, it will receive a zero]. I'll grade your work based on its own merits. I've found that AI-produced content will typically earn a ✓− (50%) or lower on my check-based grading system without me even needing to look for clues that it might have come from an LLM. Remember that text generated by these platforms is philosophical bullshit. Since it has nothing to do with truth, it will not---by definition---earn good grades.

= Course schedule
<course-schedule>
We have no regularly scheduled meeting times.

Instead, 100% of the class content is asynchronous. You can do the readings and watch the videos on your own schedule at whatever time works best for you. Many of you work full time and you have childcare and parental care responsibilities, leaving you with only evenings for coursework. I've designed this asynchronous system with #emph[you specifically] in mind. I also can only really do teaching work at night when my kids are in bed---I recorded all these videos between like 10 PM and 2 AM. We're all in similar pandemic boats.

Each week has (1) a set of readings and an accompanying lecture, (2) a lesson, (3) an example with lots of reference code, and (4) a short assignment. The #link("./schedule.qmd")[schedule page] provides an overview of all these moving parts.

I recommend following this general process for each session:

- Do everything on the content page ()
- Work through the lesson page ()
- Complete the assignment () while referencing the example ()

= Learning in troubled times
<learning-in-troubled-times>
Life still sucks right now. None of us is really okay. #strong[We're all just pretending.]

You most likely know people who have lost their jobs, have been hospitalized, or have even died (I myself know people in all those categories). You all have increased (or possibly decreased) work responsibilities and increased family care responsibilities---you might be caring for extra people (young and/or old!) right now, and you are likely facing uncertain job prospects (or have been laid off!). You might know neighbors, relatives, or friends who have been detained or deported. You might face an uncertain legal future yourself.

#strong[I'm fully committed to making sure that you learn everything you were hoping to learn from this class!] I will make whatever accommodations I can to help you finish your problem sets, do well on your projects, and learn and understand the class material. Under ordinary conditions, I am flexible and lenient with grading and course expectations when students face difficult challenges. During these troubled times, that flexibility and leniency is intensified.

If you tell me you're having trouble, I will not judge you or think less of you. I hope you'll extend me the same grace.

You #emph[never] owe me personal information about your health (mental or physical). You are #emph[always] welcome to talk to me about things that you're going through, though. If I can't help you, I usually know somebody who can.

If you need extra help, or if you need more time with something, or if you feel like you're behind or not understanding everything, #strong[do not suffer in silence!] Talk to me! I will work with you. #strong[I promise.]

#emph[Please] sign up for a time to meet with me during student hours at #link("https://scheduler.zoom.us/andrewheiss"). I'm also available through e-mail and Discord. I've enabled notifications on my Discord account, so I'll see your messages quickly!

I want you to learn lots of things from this class (Graphic design! Fancy charts! R! ggplot!), but I primarily want you to stay healthy, balanced, and grounded during these chaotic, awful times.

= Course policies
<course-policies>
#strong[Be nice. Be honest. Don't cheat.]

We will also follow #link("https://codeofconduct.gsu.edu/")[Georgia State's Code of Conduct].

This syllabus reflects a plan for the semester. Deviations may become necessary as the course progresses.

== Student hours
<student-hours>
Please watch #link("https://vimeo.com/270014784")[this video]: \(#emph[this is not me, btw---this is a different Andrew])

#block[
]
~

Student hours are set times dedicated to all of you (most professors call these "office hours"\; I don't#footnote[There's fairly widespread misunderstanding about what office hours actually are! #link("https://www.chronicle.com/article/Can-This-Man-Change-How-Elite/245714/")[Many students often think that they are the times I #emph[shouldn't] be disturbed], which is the exact opposite of what they're for!]). This means that I will be waiting for you to talk to me (in person or remotely) with whatever questions you have. This is the best and easiest way to find me and the best chance for discussing class material and concerns.

Since my schedule is often chaotic#footnote[Shuttling 5 kids around to different sports and music lessons, parenting while my wife is in her classes (she's a PhD student at UGA), meeting and traveling for research, and so on] I don't have official permanently-set student hours every week. Instead, the best way to meet with me is to #link("https://scheduler.zoom.us/andrewheiss")[make an appointment with me here]. You can choose an online or in-person slot---if you choose an online slot, the confirmation e-mail will contain a link for a Zoom meeting. You can also find me through e-mail and Discord.

== Late work
<late-work>
My general philosophy towards late work is that I don't care if stuff is late---if you turn it in, great! In past versions of this class (and other of my classes), I would have no late penalties and accept late work until the very end of the semester.

While many students have appreciated the flexibility of this system, I've received #emph[a lot] of feedback from students that such a system actually hurts them. With total freedom and no hard deadlines, lots of people put off assignments until the end and then end up not learning much and feel incredibly stressed for weeks and weeks.

So to counter this, #strong[I use kinda-sorta-hard-ish deadlines] to help you stay on schedule but also provide flexibility when needed.

You will lose 0.5 points per day for each day an exercise is late. This is designed to not be a huge penalty (3 days late = 18.5/20 points on an exercise/session check-in that gets a ✓), but instead is a commitment device to help you stay on schedule.

I will (typically) not accept work that is more than two weeks late. Again, this is not designed to be punitive---this is to help keep you on schedule. Being four or five weeks behind will only make you fall even more behind. HOWEVER if you have extenuating circumstances, I'm more than happy to accommodate. Just check in with me and let me know what's up.

== Counseling and Psychological Services (CPS)
<counseling-and-psychological-services-cps>
Life at GSU can be complicated and challenging (especially during a pandemic!). You might feel overwhelmed, experience anxiety or depression, or struggle with relationships or family responsibilities. #link("https://education.gsu.edu/cps/")[Counseling and Psychological Services (CPS)] provides free, #emph[confidential] support for students who are struggling with mental health and emotional challenges. The CPS office is staffed by professional psychologists who are attuned to the needs of all types of college and professional students. Please do not hesitate to contact CPS for assistance---getting help is a smart and courageous thing to do.

== Basic needs security
<basic-needs-security>
If you have difficulty affording groceries or accessing sufficient food to eat every day, or if you lack a safe and stable place to live, and you believe this may affect your performance in this course, please contact the #link("https://deanofstudents.gsu.edu/")[Dean of Students] for support. They can provide a host of services including free groceries from the #link("https://nutrition.gsu.edu/panther-pantry/")[Panther Pantry] and assisting with homelessness with the #link("https://deanofstudents.gsu.edu/student-assistance/embark/")[Embark Network]. Additionally, please talk to me if you are comfortable in doing so. This will enable me to provide any resources that I might possess.

== Lauren's Promise
<laurens-promise>
#strong[I will listen and believe you if someone is threatening you.]

Lauren McCluskey, a 21-year-old honors student athlete, #link("https://www.sltrib.com/opinion/commentary/2019/02/10/commentary-failing-lauren/")[was murdered on October 22, 2018 by a man she briefly dated on the University of Utah campus]. We must all take action to ensure that this never happens again.

If you are in immediate danger, call 911 or GSU police (404-413-3333).

If you are experiencing sexual assault, domestic violence, or stalking, please report it to me and I will connect you to resources or call #link("https://counselingcenter.gsu.edu/crisis-services/concern-self/immediate-help/")[GSU's Counseling and Psychological Services] (404-413-1640).

Any form of sexual harassment or violence will not be excused or tolerated at Georgia State. GSU has instituted procedures to respond to violations of these laws and standards, programs aimed at the prevention of such conduct, and intervention on behalf of the victims. Georgia State University Police officers will treat victims of sexual assault, domestic violence, and stalking with respect and dignity. Advocates on campus and in the community can help with victims' physical and emotional health, reporting options, and academic concerns.

== Academic honesty
<academic-honesty>
Violation of #link("https://deanofstudents.gsu.edu/faculty-staff-resources/academic-honesty/")[GSU's Policy on Academic Honesty] will result in an F in the course and possible disciplinary action.#footnote[So seriously, just don't cheat or plagiarize!] All violations will be formally reported to the Dean of Students.

== Special needs
<special-needs>
Students who wish to request accommodation for a disability may do so by registering with the #link("https://disability.gsu.edu/")[Office of Disability Services]. Students may only be accommodated upon issuance by the Office of Disability Services of a signed #link("https://disability.gsu.edu/services/how-to-register/")[Accommodation Plan] and are responsible for providing a copy of that plan to instructors of all classes in which accommodations are sought.

Students with special needs should then make an appointment with me during the first week of class to discuss any accommodations that need to be made.

= Assignments and grades
<assignments-and-grades>
You can find descriptions for all the assignments on the #link("./assignment/index.qmd")[assignments page].

#centered-table[
#show figure: set block(breakable: true)

#block[ // start block

  #let style-dict = (
    // tinytable style-dict after
    "7_0": 0, "7_1": 0, "7_2": 0
  )

  #let style-array = ( 
    // tinytable cell style after
    (bold: true,),
  )

  // Helper function to get cell style
  #let get-style(x, y) = {
    let key = str(y) + "_" + str(x)
    if key in style-dict { style-array.at(style-dict.at(key)) } else { none }
  }

  // tinytable align-default-array before
  #let align-default-array = ( left, left, left, ) // tinytable align-default-array here
  #show table.cell: it => {
    if style-array.len() == 0 { return it }
    
    let style = get-style(it.x, it.y)
    if style == none { return it }
    
    let tmp = it
    if ("fontsize" in style) { tmp = text(size: style.fontsize, tmp) }
    if ("color" in style) { tmp = text(fill: style.color, tmp) }
    if ("indent" in style) { tmp = pad(left: style.indent, tmp) }
    if ("underline" in style) { tmp = underline(tmp) }
    if ("italic" in style) { tmp = emph(tmp) }
    if ("bold" in style) { tmp = strong(tmp) }
    if ("mono" in style) { tmp = math.mono(tmp) }
    if ("strikeout" in style) { tmp = strike(tmp) }
    if ("smallcaps" in style) { tmp = smallcaps(tmp) }
    tmp
  }

  #align(center, [

  #table( // tinytable table start
    columns: (auto, auto, auto),
    stroke: none,
    rows: auto,
    align: (x, y) => {
      let style = get-style(x, y)
      if style != none and "align" in style { style.align } else { left }
    },
    fill: (x, y) => {
      let style = get-style(x, y)
      if style != none and "background" in style { style.background }
    },
 table.hline(y: 1, start: 0, end: 3, stroke: 0.05em + black),
 table.hline(y: 1, start: 0, end: 3, stroke: 0.05em + rgb("#d3d8dc")),
 table.hline(y: 2, start: 0, end: 3, stroke: 0.05em + rgb("#d3d8dc")),
 table.hline(y: 3, start: 0, end: 3, stroke: 0.05em + rgb("#d3d8dc")),
 table.hline(y: 4, start: 0, end: 3, stroke: 0.05em + rgb("#d3d8dc")),
 table.hline(y: 5, start: 0, end: 3, stroke: 0.05em + rgb("#d3d8dc")),
 table.hline(y: 6, start: 0, end: 3, stroke: 0.05em + rgb("#d3d8dc")),
 table.hline(y: 7, start: 0, end: 3, stroke: 0.05em + rgb("#d3d8dc")),
 table.hline(y: 8, start: 0, end: 3, stroke: 0.05em + rgb("#d3d8dc")),
 table.hline(y: 8, start: 0, end: 3, stroke: 0.1em + black),
 table.hline(y: 0, start: 0, end: 3, stroke: 0.1em + black),
 table.hline(y: 7, start: 0, end: 3, stroke: 0.1em + rgb("#d3d8dc")),
    // tinytable lines before

    // tinytable header start
    table.header(
      repeat: true,
[Assignment], [Points], [Percent],
    ),
    // tinytable header end

    // tinytable cell content after
[Session check\-ins (15 × 10)], [150], [22.1%],
[Exercises (15 × 10)], [150], [22.1%],
[\#TidyTuesday], [30], [4.4%],
[Mini project 1], [75], [11.0%],
[Mini project 2], [75], [11.0%],
[Final project], [200], [29.4%],
[Total], [680], [100.0%],

    // tinytable footer after

  ) // end table

  ]) // end align

] // end block
]
#centered-table[
#show figure: set block(breakable: true)

#block[ // start block

  #let style-dict = (
    // tinytable style-dict after
  )

  #let style-array = ( 
    // tinytable cell style after
  )

  // Helper function to get cell style
  #let get-style(x, y) = {
    let key = str(y) + "_" + str(x)
    if key in style-dict { style-array.at(style-dict.at(key)) } else { none }
  }

  // tinytable align-default-array before
  #let align-default-array = ( left, left, left, left, ) // tinytable align-default-array here
  #show table.cell: it => {
    if style-array.len() == 0 { return it }
    
    let style = get-style(it.x, it.y)
    if style == none { return it }
    
    let tmp = it
    if ("fontsize" in style) { tmp = text(size: style.fontsize, tmp) }
    if ("color" in style) { tmp = text(fill: style.color, tmp) }
    if ("indent" in style) { tmp = pad(left: style.indent, tmp) }
    if ("underline" in style) { tmp = underline(tmp) }
    if ("italic" in style) { tmp = emph(tmp) }
    if ("bold" in style) { tmp = strong(tmp) }
    if ("mono" in style) { tmp = math.mono(tmp) }
    if ("strikeout" in style) { tmp = strike(tmp) }
    if ("smallcaps" in style) { tmp = smallcaps(tmp) }
    tmp
  }

  #align(center, [

  #table( // tinytable table start
    columns: (auto, auto, auto, auto),
    stroke: none,
    rows: auto,
    align: (x, y) => {
      let style = get-style(x, y)
      if style != none and "align" in style { style.align } else { left }
    },
    fill: (x, y) => {
      let style = get-style(x, y)
      if style != none and "background" in style { style.background }
    },
 table.hline(y: 1, start: 0, end: 4, stroke: 0.05em + black),
 table.hline(y: 1, start: 0, end: 4, stroke: 0.05em + rgb("#d3d8dc")),
 table.hline(y: 2, start: 0, end: 4, stroke: 0.05em + rgb("#d3d8dc")),
 table.hline(y: 3, start: 0, end: 4, stroke: 0.05em + rgb("#d3d8dc")),
 table.hline(y: 4, start: 0, end: 4, stroke: 0.05em + rgb("#d3d8dc")),
 table.hline(y: 5, start: 0, end: 4, stroke: 0.05em + rgb("#d3d8dc")),
 table.hline(y: 6, start: 0, end: 4, stroke: 0.05em + rgb("#d3d8dc")),
 table.hline(y: 7, start: 0, end: 4, stroke: 0.05em + rgb("#d3d8dc")),
 table.hline(y: 7, start: 0, end: 4, stroke: 0.1em + black),
 table.hline(y: 0, start: 0, end: 4, stroke: 0.1em + black),
 table.hline(y: 1, start: 0, end: 4, stroke: 0.1em + rgb("#d3d8dc")),
    // tinytable lines before

    // tinytable header start
    table.header(
      repeat: true,
[Grade], [Range], [Grade], [Range],
    ),
    // tinytable header end

    // tinytable cell content after
[A], [93–100%], [C], [73–76%],
[A−], [90–92%], [C−], [70–72%],
[B+], [87–89%], [D+], [67–69%],
[B], [83–86%], [D], [63–66%],
[B−], [80–82%], [D−], [60–62%],
[C+], [77–79%], [F], [< 60%],

    // tinytable footer after

  ) // end table

  ]) // end align

] // end block
]
= Recipes
<recipes>
Once you have read this entire syllabus and #link("./assignment/index.qmd")[the assignments page], post your #strong[favorite recipe] (either a link or the text) to the #NormalTok("#recipes"); channel on Discord. I love cooking (#link("https://bsky.app/search?q=from%3Aandrew.heiss.phd+%23pacooks")[see here for a feed of some of my cooking adventures]) and I'm always on the lookout for new things!

= Schedule
<schedule>
#schedule-table[
#show figure: set block(breakable: true)

#block[ // start block

  #let style-dict = (
    // tinytable style-dict after
    "1_0": 0, "2_0": 0, "5_0": 0, "6_0": 0, "10_0": 0, "11_0": 0, "14_0": 0, "15_0": 0, "18_0": 0, "22_0": 0, "25_0": 0, "26_0": 0, "29_0": 0, "32_0": 0, "33_0": 0, "37_0": 0, "1_1": 0, "2_1": 0, "5_1": 0, "6_1": 0, "10_1": 0, "11_1": 0, "14_1": 0, "15_1": 0, "18_1": 0, "22_1": 0, "25_1": 0, "26_1": 0, "29_1": 0, "32_1": 0, "33_1": 0, "37_1": 0, "1_2": 0, "2_2": 0, "5_2": 0, "6_2": 0, "10_2": 0, "11_2": 0, "14_2": 0, "15_2": 0, "18_2": 0, "22_2": 0, "25_2": 0, "26_2": 0, "29_2": 0, "32_2": 0, "33_2": 0, "37_2": 0, "0_0": 1, "7_0": 1, "19_0": 1, "34_0": 1, "0_1": 1, "7_1": 1, "19_1": 1, "34_1": 1, "0_2": 1, "7_2": 1, "19_2": 1, "34_2": 1
  )

  #let style-array = ( 
    // tinytable cell style after
    (background: rgb("#eeeeee"),),
    (bold: true,),
  )

  // Helper function to get cell style
  #let get-style(x, y) = {
    let key = str(y) + "_" + str(x)
    if key in style-dict { style-array.at(style-dict.at(key)) } else { none }
  }

  // tinytable align-default-array before
  #let align-default-array = ( left, left, left, ) // tinytable align-default-array here
  #show table.cell: it => {
    if style-array.len() == 0 { return it }
    
    let style = get-style(it.x, it.y)
    if style == none { return it }
    
    let tmp = it
    if ("fontsize" in style) { tmp = text(size: style.fontsize, tmp) }
    if ("color" in style) { tmp = text(fill: style.color, tmp) }
    if ("indent" in style) { tmp = pad(left: style.indent, tmp) }
    if ("underline" in style) { tmp = underline(tmp) }
    if ("italic" in style) { tmp = emph(tmp) }
    if ("bold" in style) { tmp = strong(tmp) }
    if ("mono" in style) { tmp = math.mono(tmp) }
    if ("strikeout" in style) { tmp = strike(tmp) }
    if ("smallcaps" in style) { tmp = smallcaps(tmp) }
    tmp
  }

  #align(center, [

  #table( // tinytable table start
    columns: (auto, auto, auto),
    stroke: none,
    rows: auto,
    align: (x, y) => {
      let style = get-style(x, y)
      if style != none and "align" in style { style.align } else { left }
    },
    fill: (x, y) => {
      let style = get-style(x, y)
      if style != none and "background" in style { style.background }
    },
 table.hline(y: 1, start: 0, end: 3, stroke: 0.05em + black),
 table.hline(y: 8, start: 0, end: 3, stroke: 0.05em + black),
 table.hline(y: 20, start: 0, end: 3, stroke: 0.05em + black),
 table.hline(y: 35, start: 0, end: 3, stroke: 0.05em + black),
 table.hline(y: 39, start: 0, end: 3, stroke: 0.1em + black),
 table.hline(y: 0, start: 0, end: 3, stroke: 0.1em + black),
    // tinytable lines before

    // tinytable cell content after
table.cell(colspan: 3)[Foundations],
[Session 1], [January 12–January 16], [Truth, beauty, and data + R and tidyverse],
[], [January 19], [Assignment for session 1 due _(due by 11:59 PM)_],
[Session 2], [January 19–January 23], [Graphic design],
[], [January 26], [Assignment for session 2 due _(due by 11:59 PM)_],
[Session 3], [January 26–January 30], [Mapping data to graphics],
[], [February  2], [Assignment for session 3 due _(due by 11:59 PM)_],
table.cell(colspan: 3)[Core types of graphics],
[Session 4], [February  2–February  6], [Amounts and proportions],
[], [February  9], [Assignment for session 4 due _(due by 11:59 PM)_],
[Session 5], [February  9–February 13], [Themes],
[], [February 16], [Assignment for session 5 due _(due by 11:59 PM)_],
[Session 6], [February 16–February 20], [Uncertainty],
[], [February 23], [Assignment for session 6 due _(due by 11:59 PM)_],
[Session 7], [February 23–February 27], [Relationships],
[], [March  2], [Assignment for session 7 due _(due by 11:59 PM)_],
[Session 8], [March  2–March  6], [Comparisons],
[], [March  9], [Assignment for session 8 due _(due by 11:59 PM)_],
[Project], [March  9], [Mini project 1 due _(due by 11:59 PM)_],
table.cell(colspan: 3)[Special applications],
[Session 9], [March  9–March 13], [Annotations],
[], [March 23], [Assignment for session 9 due _(due by 11:59 PM)_],
[Project], [March 16–March 22], [Spring break!],
[Session 10], [March 23–March 27], [Enhancing graphics],
[], [March 30], [Assignment for session 10 due _(due by 11:59 PM)_],
[Session 11], [March 30–April  3], [Interactivity],
[], [April  6], [Assignment for session 11 due _(due by 11:59 PM)_],
[Session 12], [April  6–April 10], [Space],
[], [April 13], [Assignment for session 12 due _(due by 11:59 PM)_],
[Project], [April 13], [Mini project 2 due _(due by 11:59 PM)_],
[Session 13], [April 20–April 17], [Time],
[], [April 20], [Assignment for session 13 due _(due by 11:59 PM)_],
[Session 14], [April 20–April 24], [Text],
[], [April 27], [Assignment for session 14 due _(due by 11:59 PM)_],
table.cell(colspan: 3)[Conclusions],
[Session 15], [April 27–April 28], [Truth, beauty, and data revisited],
[], [April 28], [Assignment for session 15 due _(due by 11:59 PM)_],
[Project], [April 28], [Final deadline for \#TidyTuesday creation _(due by 11:59 PM)_],
[Project], [May  3], [Final project due _(due by 11:59 PM)_],

    // tinytable footer after

  ) // end table

  ]) // end align

] // end block
]



