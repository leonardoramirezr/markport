import Foundation

enum DefaultAssets {

    static let templateHTML = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="UTF-8">
    <title>{{ title }}</title>
    <link rel="stylesheet" href="style.css">
    </head>
    <body>
    <article class="doc">
    {{ content }}
    </article>
    </body>
    </html>
    """

    /// Base style: uses only fonts installed on the system so it
    /// works on the first try; can be changed from the editor.
    static let css = """
    /* Markport style — edit this file to change the PDF.
       Markport only injects the HTML derived from the Markdown into this sheet. */

    @page {
        size: Letter;
        margin: 0.7cm 1cm;
    }

    * {
        box-sizing: border-box;
    }

    html, body {
        margin: 0;
        padding: 0;
    }

    .doc {
        font-family: "Helvetica Neue", Helvetica, Arial, sans-serif;
        font-size: 10.5pt;
        line-height: 1.45;
        color: #1a1a1a;
    }

    /* Main title */
    .doc > h1:first-child {
        font-family: Menlo, "Courier New", monospace;
        font-size: 26pt;
        font-weight: 700;
        text-align: center;
        letter-spacing: 0.3px;
        margin: 0 0 4pt 0;
    }

    /* Subtitle below the main title */
    h1 + p {
        text-align: center;
        font-size: 9.2pt;
        margin: 0 0 16pt 0;
    }

    h2 {
        font-size: 12.5pt;
        font-weight: 700;
        text-decoration: underline;
        margin: 14pt 0 6pt 0;
    }

    h3 {
        font-size: 11pt;
        font-weight: 600;
        margin: 10pt 0 1pt 0;
    }

    h4 {
        font-size: 10.5pt;
        font-weight: 500;
        margin: 8pt 0 1pt 0;
    }

    h3 + p {
        margin: 0 0 4pt 0;
        font-size: 10.5pt;
    }

    h3 + p em {
        font-style: italic;
        font-weight: 400;
    }

    p {
        margin: 0 0 6pt 0;
        text-align: justify;
        orphans: 3;
        widows: 3;
    }

    ul {
        margin: 2pt 0 10pt 0;
        padding-left: 20pt;
        list-style: none;
    }

    li {
        position: relative;
        margin-bottom: 4pt;
        text-align: justify;
        break-inside: avoid;
    }

    li ul {
        margin: 4pt 0 4pt 0;
    }

    li::before {
        content: "\\2022";
        position: absolute;
        left: -14pt;
        font-size: 13pt;
        line-height: 1;
        color: #1a1a1a;
    }

    strong {
        font-weight: 700;
    }

    a {
        color: #1155cc;
        text-decoration: underline;
    }

    code {
        font-family: Menlo, "Courier New", monospace;
        font-size: 9.5pt;
    }

    table {
        width: 100%;
        border-collapse: collapse;
        margin: 4pt 0 10pt 0;
    }

    th, td {
        border-bottom: 0.5pt solid #d5d5d5;
        padding: 3pt 4pt;
        text-align: left;
    }

    h2, h3, h4 {
        break-after: avoid;
        break-inside: avoid;
    }
    """

    /// Sample document used for sidebar thumbnails.
    static let sampleMarkdown = """
    # Ada Lovelace

    Mexico City · ada@example.com · +52 55 0000 0000 · [linkedin.com/in/ada](https://linkedin.com)

    ## Profile

    Engineer with eight years of experience building analytical
    computing systems and automation tools for small teams.

    ## Experience

    ### Lead Engineer
    **Analytical Engine Co.** · *2021 — present*

    - Designed the notes compiler and its PDF export pipeline.
    - Cut render time by 60% through template caching.
    - Mentored three members of the platform team.

    ### Software Engineer
    **Difference Ltd.** · *2018 — 2021*

    - Migrated the document pipeline to a dependency-free architecture.

    ## Education

    ### Applied Mathematics
    **University of London** · *2014 — 2018*

    ## Skills

    Swift · WebKit · Typography · Print CSS · Automation
    """

    static let welcomeMarkdown = """
    # Document title

    Write or paste your Markdown here. The panel on the left defines
    how it will look when exported.

    ## Section

    - Point one
    - Point two
    """
}
