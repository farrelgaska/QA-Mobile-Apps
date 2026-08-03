import React from 'react';
import {
  ResponsiveContainer,
  ComposedChart,
  Area,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
} from 'recharts';
import { useReports } from '../../app/ReportsContext';
import { buildRecentWeeklyReportTrend } from '../../utils/reportTrend';

export const ReportChart: React.FC = () => {
  const { reports } = useReports();

  const chartData = React.useMemo(
    () => buildRecentWeeklyReportTrend(reports),
    [reports]
  );

  const maxVal = React.useMemo(() => {
    let currentMax = 0;
    chartData.forEach(d => {
      if (d.Laporan > currentMax) currentMax = d.Laporan;
      if (d.Disetujui > currentMax) currentMax = d.Disetujui;
    });
    return currentMax;
  }, [chartData]);

  const yAxisDomain = React.useMemo(() => {
    if (maxVal <= 3) {
      return [0, 3];
    }
    const maxTicks = Math.ceil(maxVal * 1.15); // rounded integer maximum with small top padding
    const cleanMax = Math.max(3, Math.ceil(maxTicks));
    return [0, cleanMax];
  }, [maxVal]);

  const yAxisTicks = React.useMemo(() => {
    const [, max] = yAxisDomain;
    if (max <= 5) {
      const ticks = [];
      for (let i = 0; i <= max; i++) {
        ticks.push(i);
      }
      return ticks;
    }
    return undefined; // Let Recharts scale automatically with integer ticks
  }, [yAxisDomain]);

  return (
    <div className="w-full h-[300px]">
      <ResponsiveContainer width="100%" height="100%">
        <ComposedChart
          data={chartData}
          margin={{ top: 10, right: 10, left: -20, bottom: 0 }}
        >
          <defs>
            <linearGradient id="colorLaporan" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor="#006B5A" stopOpacity={0.32}/>
              <stop offset="95%" stopColor="#006B5A" stopOpacity={0}/>
            </linearGradient>
            <linearGradient id="colorDisetujui" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor="#10B981" stopOpacity={0.24}/>
              <stop offset="95%" stopColor="#10B981" stopOpacity={0}/>
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#F3F4F6" />
          <XAxis 
            dataKey="name" 
            interval="preserveStartEnd"
            minTickGap={24}
            axisLine={false} 
            tickLine={false} 
            tick={{ fill: '#9CA3AF', fontSize: 11 }}
          />
          <YAxis 
            domain={yAxisDomain}
            ticks={yAxisTicks}
            allowDecimals={false}
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
            stroke="none"
            fillOpacity={1}
            fill="url(#colorLaporan)"
            tooltipType="none"
          />
          <Area
            type="monotone"
            dataKey="Disetujui"
            stroke="none"
            fillOpacity={1}
            fill="url(#colorDisetujui)"
            tooltipType="none"
          />
          <Line
            type="monotone"
            dataKey="Laporan"
            name="Total Laporan"
            stroke="#006B5A"
            strokeWidth={2.5}
            dot={false}
            activeDot={{ r: 4 }}
          />
          <Line
            type="monotone"
            dataKey="Disetujui"
            name="Disetujui"
            stroke="#10B981"
            strokeWidth={2.5}
            dot={false}
            activeDot={{ r: 4 }}
          />
        </ComposedChart>
      </ResponsiveContainer>
    </div>
  );
};
