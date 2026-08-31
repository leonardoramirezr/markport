import Foundation

enum DefaultAssets {

    static let templateHTML = """
    <!DOCTYPE html>
    <html lang="es">
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

    /// Estilo base: usa únicamente fuentes instaladas en el sistema para que
    /// funcione al primer intento; se puede cambiar desde el editor.
    static let css = """
    /* Estilo Markport — edita este archivo para cambiar el PDF.
       Markport solo inyecta el HTML derivado del Markdown en esta hoja. */

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

    /* Título principal */
    .doc > h1:first-child {
        font-family: Menlo, "Courier New", monospace;
        font-size: 26pt;
        font-weight: 700;
        text-align: center;
        letter-spacing: 0.3px;
        margin: 0 0 4pt 0;
    }

    /* Subtítulo bajo el título principal */
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

    /// Documento de muestra usado en las miniaturas de la barra lateral.
    static let sampleMarkdown = """
    # Ada Lovelace

    Ciudad de México · ada@ejemplo.com · +52 55 0000 0000 · [linkedin.com/in/ada](https://linkedin.com)

    ## Perfil

    Ingeniera con ocho años de experiencia construyendo sistemas de cálculo
    analítico y herramientas de automatización para equipos pequeños.

    ## Experiencia

    ### Ingeniera principal
    **Analytical Engine Co.** · *2021 — presente*

    - Diseño del compilador de notas y su cadena de exportación a PDF.
    - Reducción del tiempo de render en 60% mediante cacheo de plantillas.
    - Mentoría a tres personas del equipo de plataforma.

    ### Ingeniera de software
    **Difference Ltd.** · *2018 — 2021*

    - Migración del pipeline de documentos a una arquitectura sin dependencias.

    ## Educación

    ### Matemáticas Aplicadas
    **Universidad de Londres** · *2014 — 2018*

    ## Habilidades

    Swift · WebKit · Tipografía · CSS de impresión · Automatización
    """

    static let welcomeMarkdown = """
    # Título del documento

    Escribe o pega aquí tu Markdown. El panel de la izquierda define
    cómo se verá al exportar.

    ## Sección

    - Punto uno
    - Punto dos
    """
}
