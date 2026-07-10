import React from 'react';
import {
  ResponsiveContainer,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
} from 'recharts';

const dummyData = [
  { name: 'Minggu 1', Laporan: 12, Disetujui: 10, Perbaikan: 2 },
  { name: 'Minggu 2', Laporan: 19, Disetujui: 15, Perbaikan: 4 },
  { name: 'Minggu 3', Laporan: 15, Disetujui: 12, Perbaikan: 3 },
  { name: 'Minggu 4', Laporan: 28, Disetujui: 24, Perbaikan: 4 },
  { name: 'Minggu 5', Laporan: 22, Disetujui: 18, Perbaikan: 4 },
  { name: 'Minggu 6', Laporan: 35, Disetujui: 30, Perbaikan: 5 },
];

export const ReportChart: React.FC = () => {
  return (
    <div className="w-full h-[300px]">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart
          data={dummyData}
          margin={{ top: 10, right: 10, left: -20, bottom: 0 }}
        >
          <defs>
            <linearGradient id="colorLaporan" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor="#006B5A" stopOpacity={0.2}/>
              <stop offset="95%" stopColor="#006B5A" stopOpacity={0}/>
            </linearGradient>
            <linearGradient id="colorDisetujui" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor="#10B981" stopOpacity={0.2}/>
              <stop offset="95%" stopColor="#10B981" stopOpacity={0}/>
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#F3F4F6" />
          <XAxis 
            dataKey="name" 
            axisLine={false} 
            tickLine={false} 
            tick={{ fill: '#9CA3AF', fontSize: 11 }}
          />
          <YAxis 
            axisLine={false} 
            tickLine={false} 
            tick={{ fill: '#9CA3AF', fontSize: 11 }} 
          />
          <Tooltip 
            contentStyle={{ 
              backgroundColor: '#fff', 
              border: '1px solid #E5E7EB', 
              borderRadius: '8px', 
              boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' 
            }}
          />
          <Area
            type="monotone"
            dataKey="Laporan"
            stroke="#006B5A"
            strokeWidth={2}
            fillOpacity={1}
            fill="url(#colorLaporan)"
          />
          <Area
            type="monotone"
            dataKey="Disetujui"
            stroke="#10B981"
            strokeWidth={2}
            fillOpacity={1}
            fill="url(#colorDisetujui)"
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
};
