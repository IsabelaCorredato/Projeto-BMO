import { useMemo, useState } from "react";
import { useMessages } from "@/hooks/use-messages";
import { format } from "date-fns";
import { motion } from "framer-motion";
import {
  RefreshCw,
  MessageSquare,
  Activity,
  Clock,
  Inbox,
  AlertCircle,
  BarChart3,
  List
} from "lucide-react";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  Legend
} from "recharts";

import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.1 }
  }
};

const itemVariants = {
  hidden: { opacity: 0, y: 20 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { type: "spring", stiffness: 300, damping: 24 }
  }
};

export default function Dashboard() {
  const [activeTab, setActiveTab] = useState("analytics");
  const { data, isLoading, isError, error, isRefetching, invalidate } = useMessages();

  // Derived metrics for charts and summaries
  const { totalMessages, uniqueSources, sourceDistribution, latestMessage, chartData } = useMemo(() => {
    if (!data?.data) {
      return { totalMessages: 0, uniqueSources: 0, sourceDistribution: {}, latestMessage: null, chartData: [] };
    }

    const messages = data.data;
    const total = messages.length;
    
    const distribution: Record<string, number> = {};
    let latest: Date | null = null;

    messages.forEach(msg => {
      // Source distribution
      distribution[msg.source] = (distribution[msg.source] || 0) + 1;
      
      // Latest message calculation
      const msgDate = new Date(msg.createdAt);
      if (!latest || msgDate > latest) {
        latest = msgDate;
      }
    });

    const unique = Object.keys(distribution).length;
    
    // Format for Recharts
    const chart = Object.entries(distribution)
      .map(([name, value]) => ({ name, value }))
      .sort((a, b) => b.value - a.value); // Sort descending

    return {
      totalMessages: total,
      uniqueSources: unique,
      sourceDistribution: distribution,
      latestMessage: latest,
      chartData: chart
    };
  }, [data]);

  // Chart Colors using CSS variables defined in our theme
  const COLORS = [
    'hsl(var(--chart-1))',
    'hsl(var(--chart-2))',
    'hsl(var(--chart-3))',
    'hsl(var(--chart-4))',
    'hsl(var(--chart-5))',
  ];

  if (isError) {
    return (
      <div className="min-h-screen p-8 flex items-center justify-center">
        <Alert variant="destructive" className="max-w-md">
          <AlertCircle className="h-4 w-4" />
          <AlertTitle>Connection Error</AlertTitle>
          <AlertDescription>
            {error instanceof Error ? error.message : "Failed to load dashboard data."}
          </AlertDescription>
          <Button 
            variant="outline" 
            className="mt-4 w-full" 
            onClick={() => invalidate()}
          >
            Try Again
          </Button>
        </Alert>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Sleek Header */}
      <header className="sticky top-0 z-30 glass-effect">
        <div className="max-w-7xl mx-auto px-6 h-16 flex items-center justify-between">
          <div className="flex items-center gap-2 text-foreground">
            <Activity className="h-5 w-5 text-primary" />
            <h1 className="font-display font-semibold text-lg tracking-tight">System Monitor</h1>
          </div>
          <Button 
            variant="secondary" 
            size="sm" 
            onClick={() => invalidate()} 
            disabled={isRefetching || isLoading}
            className="rounded-full shadow-sm"
          >
            <RefreshCw className={`h-4 w-4 mr-2 ${isRefetching ? 'animate-spin' : ''}`} />
            {isRefetching ? 'Syncing...' : 'Refresh Data'}
          </Button>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-6 py-8">
        <motion.div
          variants={containerVariants}
          initial="hidden"
          animate="visible"
          className="space-y-8"
        >
          {/* Tabs Navigation */}
          <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
            <TabsList className="grid w-full max-w-xs grid-cols-2">
              <TabsTrigger value="analytics" className="flex items-center gap-2">
                <BarChart3 className="h-4 w-4" />
                <span className="hidden sm:inline">Analytics</span>
              </TabsTrigger>
              <TabsTrigger value="messages" className="flex items-center gap-2">
                <List className="h-4 w-4" />
                <span className="hidden sm:inline">Messages</span>
              </TabsTrigger>
            </TabsList>

            {/* Analytics Tab */}
            <TabsContent value="analytics" className="space-y-8 mt-8">
          {/* Summary Cards */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <motion.div variants={itemVariants}>
              <Card className="shadow-soft border-border/50 bg-card/50 backdrop-blur-sm">
                <CardHeader className="flex flex-row items-center justify-between pb-2">
                  <CardTitle className="text-sm font-medium text-muted-foreground uppercase tracking-wider">
                    Total Messages
                  </CardTitle>
                  <MessageSquare className="h-4 w-4 text-muted-foreground" />
                </CardHeader>
                <CardContent>
                  {isLoading ? (
                    <Skeleton className="h-8 w-20" />
                  ) : (
                    <div className="text-3xl font-display font-semibold text-foreground">
                      {totalMessages.toLocaleString()}
                    </div>
                  )}
                </CardContent>
              </Card>
            </motion.div>

            <motion.div variants={itemVariants}>
              <Card className="shadow-soft border-border/50 bg-card/50 backdrop-blur-sm">
                <CardHeader className="flex flex-row items-center justify-between pb-2">
                  <CardTitle className="text-sm font-medium text-muted-foreground uppercase tracking-wider">
                    Active Sources
                  </CardTitle>
                  <Activity className="h-4 w-4 text-muted-foreground" />
                </CardHeader>
                <CardContent>
                  {isLoading ? (
                    <Skeleton className="h-8 w-16" />
                  ) : (
                    <div className="text-3xl font-display font-semibold text-foreground">
                      {uniqueSources}
                    </div>
                  )}
                </CardContent>
              </Card>
            </motion.div>

            <motion.div variants={itemVariants}>
              <Card className="shadow-soft border-border/50 bg-card/50 backdrop-blur-sm">
                <CardHeader className="flex flex-row items-center justify-between pb-2">
                  <CardTitle className="text-sm font-medium text-muted-foreground uppercase tracking-wider">
                    Latest Activity
                  </CardTitle>
                  <Clock className="h-4 w-4 text-muted-foreground" />
                </CardHeader>
                <CardContent>
                  {isLoading ? (
                    <Skeleton className="h-8 w-32" />
                  ) : (
                    <div className="text-xl font-display font-medium text-foreground mt-1">
                      {latestMessage ? format(latestMessage, 'HH:mm:ss.SSS') : '—'}
                    </div>
                  )}
                </CardContent>
              </Card>
            </motion.div>
          </div>

            {/* Charts Section */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <motion.div variants={itemVariants}>
              <Card className="shadow-soft border-border/50">
                <CardHeader>
                  <CardTitle className="font-display">Traffic by Source</CardTitle>
                  <CardDescription>Volume of messages per origin</CardDescription>
                </CardHeader>
                <CardContent>
                  {isLoading ? (
                    <Skeleton className="h-[300px] w-full rounded-lg" />
                  ) : chartData.length > 0 ? (
                    <div className="h-[300px] w-full mt-4">
                      <ResponsiveContainer width="100%" height="100%">
                        <BarChart data={chartData} margin={{ top: 0, right: 0, left: -20, bottom: 0 }}>
                          <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
                          <XAxis 
                            dataKey="name" 
                            axisLine={false}
                            tickLine={false}
                            tick={{ fill: 'hsl(var(--muted-foreground))', fontSize: 12 }}
                            dy={10}
                          />
                          <YAxis 
                            axisLine={false}
                            tickLine={false}
                            tick={{ fill: 'hsl(var(--muted-foreground))', fontSize: 12 }}
                          />
                          <Tooltip 
                            cursor={{ fill: 'hsl(var(--accent))', opacity: 0.4 }}
                            contentStyle={{ 
                              backgroundColor: 'hsl(var(--popover))',
                              borderColor: 'hsl(var(--border))',
                              borderRadius: '8px',
                              boxShadow: '0 4px 12px rgba(0,0,0,0.1)'
                            }}
                            itemStyle={{ color: 'hsl(var(--foreground))' }}
                          />
                          <Bar dataKey="value" fill="hsl(var(--primary))" radius={[4, 4, 0, 0]} />
                        </BarChart>
                      </ResponsiveContainer>
                    </div>
                  ) : (
                    <div className="h-[300px] flex items-center justify-center text-muted-foreground flex-col gap-2">
                      <Inbox className="h-8 w-8 opacity-20" />
                      <p>No data available</p>
                    </div>
                  )}
                </CardContent>
              </Card>
            </motion.div>

            <motion.div variants={itemVariants}>
              <Card className="shadow-soft border-border/50">
                <CardHeader>
                  <CardTitle className="font-display">Source Distribution</CardTitle>
                  <CardDescription>Proportional breakdown of origins</CardDescription>
                </CardHeader>
                <CardContent>
                  {isLoading ? (
                    <Skeleton className="h-[300px] w-full rounded-lg" />
                  ) : chartData.length > 0 ? (
                    <div className="h-[300px] w-full mt-4">
                      <ResponsiveContainer width="100%" height="100%">
                        <PieChart>
                          <Pie
                            data={chartData}
                            cx="50%"
                            cy="50%"
                            innerRadius={70}
                            outerRadius={100}
                            paddingAngle={2}
                            dataKey="value"
                            stroke="none"
                          >
                            {chartData.map((_, index) => (
                              <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                            ))}
                          </Pie>
                          <Tooltip 
                            contentStyle={{ 
                              backgroundColor: 'hsl(var(--popover))',
                              borderColor: 'hsl(var(--border))',
                              borderRadius: '8px'
                            }}
                            itemStyle={{ color: 'hsl(var(--foreground))' }}
                          />
                          <Legend 
                            verticalAlign="bottom" 
                            height={36}
                            iconType="circle"
                            formatter={(value) => <span className="text-foreground text-sm">{value}</span>}
                          />
                        </PieChart>
                      </ResponsiveContainer>
                    </div>
                  ) : (
                    <div className="h-[300px] flex items-center justify-center text-muted-foreground flex-col gap-2">
                      <Inbox className="h-8 w-8 opacity-20" />
                      <p>No data available</p>
                    </div>
                  )}
                </CardContent>
              </Card>
            </motion.div>
            </div>
            </TabsContent>

            {/* Messages Tab */}
            <TabsContent value="messages" className="mt-8">
              <motion.div variants={itemVariants}>
                <Card className="shadow-soft border-border/50 overflow-hidden">
                  <CardHeader className="border-b border-border/50 bg-muted/20">
                    <div className="flex items-center justify-between">
                      <div>
                        <CardTitle className="font-display text-lg">All Messages</CardTitle>
                        <CardDescription>Complete log of all ingested messages</CardDescription>
                      </div>
                      <div className="text-sm font-medium text-muted-foreground">
                        {data?.count || 0} messages
                      </div>
                    </div>
                  </CardHeader>
                  <div className="overflow-x-auto">
                    <Table>
                      <TableHeader className="bg-transparent hover:bg-transparent">
                        <TableRow className="border-border/50 hover:bg-transparent">
                          <TableHead className="w-[100px] font-medium">ID</TableHead>
                          <TableHead className="font-medium">Timestamp</TableHead>
                          <TableHead className="font-medium">Source</TableHead>
                          <TableHead className="font-medium">Message</TableHead>
                        </TableRow>
                      </TableHeader>
                      <TableBody>
                        {isLoading ? (
                          Array.from({ length: 8 }).map((_, i) => (
                            <TableRow key={i} className="border-border/50">
                              <TableCell><Skeleton className="h-4 w-8" /></TableCell>
                              <TableCell><Skeleton className="h-4 w-32" /></TableCell>
                              <TableCell><Skeleton className="h-5 w-20 rounded-full" /></TableCell>
                              <TableCell><Skeleton className="h-4 w-full max-w-lg" /></TableCell>
                            </TableRow>
                          ))
                        ) : data?.data && data.data.length > 0 ? (
                          // Sort by createdAt descending
                          [...data.data]
                            .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
                            .map((msg) => (
                              <TableRow key={msg.id} className="border-border/50 transition-colors hover:bg-muted/30">
                                <TableCell className="font-mono text-muted-foreground text-xs">
                                  {msg.id}
                                </TableCell>
                                <TableCell className="whitespace-nowrap text-sm">
                                  {format(new Date(msg.createdAt), 'MMM d, HH:mm:ss.SSS')}
                                </TableCell>
                                <TableCell>
                                  <Badge variant="secondary" className="font-mono text-xs px-2 py-0.5 rounded-md bg-secondary text-secondary-foreground">
                                    {msg.source}
                                  </Badge>
                                </TableCell>
                                <TableCell className="text-sm">
                                  <span className="font-mono text-xs bg-muted/50 px-2 py-1 rounded text-muted-foreground block max-w-xl truncate">
                                    {msg.text}
                                  </span>
                                </TableCell>
                              </TableRow>
                            ))
                        ) : (
                          <TableRow>
                            <TableCell colSpan={4} className="h-32 text-center text-muted-foreground">
                              <div className="flex flex-col items-center justify-center gap-2">
                                <Inbox className="h-8 w-8 opacity-20" />
                                <p>No messages recorded yet.</p>
                              </div>
                            </TableCell>
                          </TableRow>
                        )}
                      </TableBody>
                    </Table>
                  </div>
                </Card>
              </motion.div>
            </TabsContent>
          </Tabs>
        </motion.div>
      </main>
    </div>
  );
}
