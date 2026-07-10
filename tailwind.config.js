/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#006B5A',
          hover: '#005245',
          light: '#E7F5F1',
        },
        bgApp: '#F7F9F8',
      }
    },
  },
  plugins: [],
}
