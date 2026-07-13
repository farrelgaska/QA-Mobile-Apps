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
import { useReports } from '../../app/ReportsContext';

export const ReportChart: React.FC = () => {
  const { reports } = useReports();

  const chartData = React.useMemo(() => {
    if (!reports || reports.length === 0) {
      return [{ name: 'Belum Ada Laporan', Laporan: 0, Disetujui: 0 }];
    }

    const groups: { [key: string]: { monday: Date; Laporan: number; Disetujui: number } } = {};

    reports.forEach(report => {
      if (!report.submittedAt) return;
      const d = new Date(report.submittedAt);
      if (isNaN(d.getTime())) return;

      // Find Monday of the week
      const day = d.getDay();
      const diff = d.getDate() - day + (day === 0 ? -6 : 1);
      const monday = new Date(d.setDate(diff));
      monday.setHours(0, 0, 0, 0);

      const key = monday.getTime().toString();
      if (!groups[key]) {
        groups[key] = {
          monday,
          Laporan: 0,
          Disetujui: 0,
        };
      }
      groups[key].Laporan += 1;
      if (report.status === 'APPROVED') {
        groups[key].Disetujui += 1;
      }
    });

    // Sort chronologically by Monday date
    const sortedKeys = Object.keys(groups).sort((a, b) => Number(a) - Number(b));
    return sortedKeys.map(key => {
      const g = groups[key];
      const dayStr = String(g.monday.getDate()).padStart(2, '0');
      const monthStr = String(g.monday.getMonth() + 1).padStart(2, '0');
      return {
        name: `Mgu ${dayStr}/${monthStr}`,
        Laporan: g.Laporan,
        Disetujui: g.Disetujui,
      };
    });
  }, [reports]);

  return (
    <div className="w-full h-[300px]">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart
          data={chartData}
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
