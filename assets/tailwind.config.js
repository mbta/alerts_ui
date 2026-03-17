// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/*_web.ex",
    "../lib/*_web/**/*.*ex"
  ],
  theme: {
    extend: {
      colors: {
        primary: "#8ecdff",
        secondary: "#171f26",
        success: "#a7ffeb",
        warning: "#ffc107",
        danger: "#dc3545",
        "primary-hover": "#C1E4FF",
        "primary-border-hover": "#C1E4FF",
        "primary-active": "#74a5cc",
        "primary-disabled": "#628cae",
        "secondary-border": "#495057",
        "secondary-hover": "#0b2f4c",
        "secondary-hover-border": "#8AC6F6",
        "secondary-active": "#74a5cc",
        "secondary-focus-border": "#8ECDFF",
        "secondary-focus-shadow": "#4F718B",
        "secondary-disabled": "#628CAE",
        "danger-active": "#fb5262",
        "danger-hover": "#f77380",
        "danger-disabled": "#a64f57",
        "toggle-active": "#485E70",
        "bg-primary": "#0f1417",
        "bg-secondary": "#171f26",
        "bg-elevation-3": "#1e2933",
        "bg-elevation-4": "#2b3741",
        "bg-elevation-5": "#2e3f4d",
        "bg-elevation-6": "#384e5c",
        "bg-input-default": "#2e3f4d",
        "menu-active": "#c1e4ff",
        "border-primary": "#384E5C",
        "border-focus": "#8ecdff",
        "border-disabled": "#c6c6c9",
        "text-primary": "#f8f9fa",
        "text-primary-disabled": "#1B1F23",
        "text-danger-disabled": "#C1C1C1",
        "text-toggle-disabled": "#8B8B8B",
        "text-secondary": "#6c757d",
        "text-disabled": "#c6c6c9",
        "text-link-outline": "#8ecdff",
        "text-error": "#ffb4ab",
        "text-invert": "#212529",
        "text-white": "#ffffff",
        "text-dark": "#212529",
        "mbta-commuter-rail": "#80276c",
        "mbta-subway": "#494f5b",
        "mbta-bus": "#ffc72c",
        "mbta-ferry": "#008eaa",
        "mbta-the-ride": "#52bbc5",
        "mbta-red": "#da291c",
        "mbta-orange": "#ed8b00",
        "mbta-green": "#00843d",
        "mbta-blue": "#003da5",
        "mbta-silver": "#6c777e",
        "mbta-access": "#165C96",
        transparent: "transparent",
        current: "currentColor",
      }
    },
    fontFamily: {
      "body": ["Inter UI", "Helvetica Neue", "Helvetica", "Arial", "sans-serif"],
    },
    fontSize: {
      "xs": ["0.75rem", "0.75rem"],
      "sm": ["0.875rem", "1.25rem"],
      "base": ["1rem", "1.5rem"],
      "lg": ["1.25rem", "1.5rem"],
      "xl": ["1.25rem", "1.75rem"],
      "2xl": ["1.75rem", "2.1rem"],
      "3xl": ["2rem", "2.4rem"],
      "4xl": ["2.5rem", "3rem"],
    },
    gridTemplateColumns: {
      1: "1fr",
      3: "repeat(3, 1fr)",
      4: "repeat(4, 1fr)",
      6: "repeat(6, 1fr)",
      "review-modal": "1fr 13.875rem",
    },
  },
  daisyui: {
    logs: false,
    themes: ["winter"],
  },
  plugins: [
    require("@tailwindcss/typography"),
    require("daisyui"),
    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({addVariant}) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
    plugin(({addVariant}) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
    plugin(({addVariant}) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"])),

    // Embeds Heroicons (https://heroicons.com) into your app.css bundle
    // See your `CoreComponents.icon/1` for more information.
    //
    plugin(function({matchComponents, theme}) {
      let iconsDir = path.join(__dirname, "./vendor/heroicons/optimized")
      let values = {}
      let icons = [
        ["", "/24/outline"],
        ["-solid", "/24/solid"],
        ["-mini", "/20/solid"]
      ]
      icons.forEach(([suffix, dir]) => {
        fs.readdirSync(path.join(iconsDir, dir)).map(file => {
          let name = path.basename(file, ".svg") + suffix
          values[name] = {name, fullPath: path.join(iconsDir, dir, file)}
        })
      })
      matchComponents({
        "hero": ({name, fullPath}) => {
          let content = fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, "")
          return {
            [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
            "-webkit-mask": `var(--hero-${name})`,
            "mask": `var(--hero-${name})`,
            "mask-repeat": "no-repeat",
            "background-color": "currentColor",
            "vertical-align": "middle",
            "display": "inline-block",
            "width": theme("spacing.5"),
            "height": theme("spacing.5")
          }
        }
      }, {values})
    })
  ]
}
