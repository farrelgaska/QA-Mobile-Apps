import { RouterProvider } from 'react-router-dom';
import { router } from './router';
import { ReportsProvider } from './ReportsContext';

function App() {
  return (
    <ReportsProvider>
      <RouterProvider router={router} />
    </ReportsProvider>
  );
}

export default App;
