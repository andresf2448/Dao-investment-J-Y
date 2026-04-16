/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: "#3A6FF7",
          hover: "#2F5CE0",
          light: "#6EA8FF"
        },
        background: "#F5F7FB",
        surface: "#FFFFFF",
        border: "#E6EAF0",
        text: {
          primary: "#1A1F36",
          secondary: "#6B7280"
        },
        success: "#2CB67D",
        warning: "#F5A623",
        danger: "#E5484D"
      },
      boxShadow: {
        card: "0 4px 12px rgba(0, 0, 0, 0.04)"
      },
      borderRadius: {
        xl: "12px"
      }
    }
  },
  plugins: []
};