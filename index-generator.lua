local yaml = require("yaml")

function Pandoc(doc)
  -- Leer el YAML del proyecto
  local config = yaml.loadfile("_quarto.yml")

  local sidebar = config.website.sidebar.contents

  local blocks = {}

  -- Título principal
  table.insert(blocks, pandoc.Header(1, "Índice de Contenidos"))

  -- Recorrer secciones
  for _, section in ipairs(sidebar) do
    table.insert(blocks, pandoc.Header(2, section.section))

    local items = {}

    for _, item in ipairs(section.contents) do
      local link = string.format("[%s](%s)", item.text, item.href)
      table.insert(items, pandoc.Para(pandoc.RawInline("markdown", link)))
    end

    table.insert(blocks, pandoc.BulletList(items))
  end

  return pandoc.Pandoc(blocks, doc.meta)
end
