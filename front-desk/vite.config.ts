import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react-swc'

// https://vitejs.dev/config/
export default defineConfig({
    plugins: [react()],
    build: {
        rollupOptions: {
            input: [
                'editor/index.html',
                'analysis-tutorial/index.html',
            ]
        }
    }
})
