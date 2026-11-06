/** @type {import('tailwindcss').Config} */
import animate from "tailwindcss-animate"
import containerQueries from "@tailwindcss/container-queries"

const config = {
	darkMode: ["class"],
	content: [
		"./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
		"./src/components/**/*.{js,ts,jsx,tsx,mdx}",
		"./src/app/**/*.{js,ts,jsx,tsx,mdx}",
	],
	theme: {
		container: {
			center: true,
			padding: {
				DEFAULT: '1rem',
				md: '2rem',
				lg: '2.5rem',
			},
			screens: {
				sm: '540px',
				md: '720px',
				lg: '960px',
				xl: '1280px',
				'2xl': '1536px',
				// Main content width cap on large screens.
				'3xl': '1660px',
			},
		},

		extend: {
			// Motion tokens — use these instead of ad-hoc duration-/ease- values so
			// every transition in the app shares one rhythm.
			transitionDuration: {
				fast: '150ms',
				base: '200ms',
				slow: '300ms',
				slower: '500ms',
			},
			transitionTimingFunction: {
				standard: 'cubic-bezier(0.2, 0, 0, 1)',
				entrance: 'cubic-bezier(0, 0, 0, 1)',
				exit: 'cubic-bezier(0.3, 0, 1, 1)',
			},
			keyframes: {
				rotation: {
					'0%': { transform: 'rotate(0deg)' },
					'100%': { transform: 'rotate(360deg)' },
				},
				pulseGlow: {
					'0%, 100%': { transform: 'scale(0.85)', opacity: '0.35' },
					'50%': { transform: 'scale(1.15)', opacity: '0.7' },
				},
				stepperIn: {
					'0%': { transform: 'scaleX(0.7)', opacity: '0.4' },
					'100%': { transform: 'scaleX(1)', opacity: '1' },
				},
				pulseOnce: {
					'0%, 100%': { transform: 'scale(1)' },
					'50%': { transform: 'scale(1.35)' },
				},
				ticketIn: {
					'0%': { transform: 'scale(0.9)', opacity: '0' },
					'60%': { transform: 'scale(1.03)', opacity: '1' },
					'100%': { transform: 'scale(1)', opacity: '1' },
				},
				iconSpinIn: {
					'0%': { transform: 'rotate(-90deg) scale(0.4)', opacity: '0' },
					'100%': { transform: 'rotate(0) scale(1)', opacity: '1' },
				},
				flipIn: {
					'0%': { transform: 'rotateX(90deg)', opacity: '0' },
					'100%': { transform: 'rotateX(0)', opacity: '1' },
				},
				fadeSwap: {
					'0%': { transform: 'scale(0.98)', opacity: '0' },
					'100%': { transform: 'scale(1)', opacity: '1' },
				},
				etaIn: {
					'0%': { transform: 'translateY(6px)', opacity: '0' },
					'100%': { transform: 'translateY(0)', opacity: '1' },
				},
				truckIn: {
					'0%': { transform: 'translateX(-12px)', opacity: '0' },
					'100%': { transform: 'translateX(0)', opacity: '1' },
				},
				truckInRtl: {
					'0%': { transform: 'translateX(12px)', opacity: '0' },
					'100%': { transform: 'translateX(0)', opacity: '1' },
				},
				qtyPop: {
					'0%': { transform: 'translateY(45%) scale(0.8)', opacity: '0' },
					'100%': { transform: 'translateY(0) scale(1)', opacity: '1' },
				},
				rowOut: {
					'0%': { opacity: '1', transform: 'translateX(0)', maxHeight: '320px' },
					'55%': { opacity: '0', transform: 'translateX(-16px)', maxHeight: '320px' },
					'100%': {
						opacity: '0',
						transform: 'translateX(-16px)',
						maxHeight: '0px',
						paddingTop: '0px',
						paddingBottom: '0px',
						marginBottom: '0px',
						borderWidth: '0px',
					},
				},
				rowIn: {
					'0%': { opacity: '0', transform: 'translateY(8px)' },
					'100%': { opacity: '1', transform: 'translateY(0)' },
				},
				contentIn: {
					'0%': { opacity: '0', transform: 'translateY(10px)' },
					'100%': { opacity: '1', transform: 'translateY(0)' },
				},
			},

			animation: {
				rotation: 'rotation 1s linear infinite',
				reverseRotation: 'rotation 1s linear infinite reverse',
				pulseGlow: 'pulseGlow 2.6s ease-in-out infinite',
				stepperIn: 'stepperIn 220ms cubic-bezier(0.34, 1.56, 0.64, 1)',
				qtyPop: 'qtyPop 180ms ease-out',
				rowOut: 'rowOut 320ms cubic-bezier(0.4, 0, 0.2, 1) forwards',
				rowIn: 'rowIn 260ms ease-out',
				contentIn: 'contentIn 280ms cubic-bezier(0.22, 1, 0.36, 1) both',
				fadeSwap: 'fadeSwap 200ms ease-out',
				flipIn: 'flipIn 260ms ease-out',
				ticketIn: 'ticketIn 380ms cubic-bezier(0.34, 1.56, 0.64, 1)',
				iconSpinIn: 'iconSpinIn 500ms cubic-bezier(0.34, 1.56, 0.64, 1) 120ms both',
				pulseOnce: 'pulseOnce 600ms ease-in-out 2',
				etaIn: 'etaIn 300ms ease-out',
				truckIn: 'truckIn 450ms cubic-bezier(0.22, 1, 0.36, 1)',
				truckInRtl: 'truckInRtl 450ms cubic-bezier(0.22, 1, 0.36, 1)',
			},
			colors: {
				secondary: '#FF3D00', // Adjust this to your desired secondary color
			},
			colors: {
				background: 'hsl(var(--background))',
				foreground: 'hsl(var(--foreground))',
				card: {
					DEFAULT: 'hsl(var(--card))',
					foreground: 'hsl(var(--card-foreground))'
				},
				popover: {
					DEFAULT: 'hsl(var(--popover))',
					foreground: 'hsl(var(--popover-foreground))'
				},
				primary: {
					DEFAULT: 'hsl(var(--primary))',
					foreground: 'hsl(var(--primary-foreground))'
				},
				secondary: {
					DEFAULT: 'hsl(var(--secondary))',
					foreground: 'hsl(var(--secondary-foreground))'
				},
				muted: {
					DEFAULT: 'hsl(var(--muted))',
					foreground: 'hsl(var(--muted-foreground))'
				},
				accent: {
					DEFAULT: 'hsl(var(--accent))',
					foreground: 'hsl(var(--accent-foreground))'
				},
				destructive: {
					DEFAULT: 'hsl(var(--destructive))',
					foreground: 'hsl(var(--destructive-foreground))'
				},
				border: 'hsl(var(--border))',
				input: 'hsl(var(--input))',
				ring: 'hsl(var(--ring))',
				chart: {
					'1': 'hsl(var(--chart-1))',
					'2': 'hsl(var(--chart-2))',
					'3': 'hsl(var(--chart-3))',
					'4': 'hsl(var(--chart-4))',
					'5': 'hsl(var(--chart-5))'
				}
			},
			borderRadius: {
				lg: 'var(--radius)',
				md: 'calc(var(--radius) - 2px)',
				sm: 'calc(var(--radius) - 4px)'
			}
		}
	},
	plugins: [animate, containerQueries],
}

export default config