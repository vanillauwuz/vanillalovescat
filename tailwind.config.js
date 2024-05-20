/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./**/*.{html,js}"],
  theme: {
    extend: {
      keyframes: {
        blink: {
          '0%, 100%': { 'border-color': 'white' },
          '50%': { 'border-color': 'transparent' },
        }
      },
      animation: {
        blink: 'blink 1s infinite',
      },
    },
  },
  plugins: [],
}