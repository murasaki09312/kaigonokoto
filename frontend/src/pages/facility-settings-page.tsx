import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Building2, MapPin } from "lucide-react";
import { toast } from "sonner";
import { getFacilitySetting, updateFacilitySetting, type ApiError } from "@/lib/api";
import type { FacilityScale } from "@/types/facility-setting";
import { useAuth } from "@/providers/auth-provider";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";

function formatApiError(error: unknown, fallbackMessage: string): string {
  if (typeof error === "object" && error !== null && "message" in error) {
    return String((error as ApiError).message);
  }
  return fallbackMessage;
}

export function FacilitySettingsPage() {
  const { permissions } = useAuth();
  const queryClient = useQueryClient();
  const canManageTenant = permissions.includes("tenants:manage");
  const [draftCityName, setDraftCityName] = useState<string | null>(null);
  const [draftFacilityScale, setDraftFacilityScale] = useState<FacilityScale | "" | null>(null);

  const facilitySettingQuery = useQuery({
    queryKey: ["facility-setting"],
    queryFn: getFacilitySetting,
    enabled: canManageTenant,
  });

  const cityName = draftCityName ?? facilitySettingQuery.data?.city_name ?? "";
  const facilityScale = draftFacilityScale ?? (facilitySettingQuery.data?.facility_scale ?? "");

  const saveMutation = useMutation({
    mutationFn: async () => {
      if (!cityName || !facilityScale) {
        throw new Error("所在地と事業所規模を選択してください");
      }

      return updateFacilitySetting({
        city_name: cityName,
        facility_scale: facilityScale,
      });
    },
    onSuccess: async () => {
      toast.success("事業所設定を更新しました");
      setDraftCityName(null);
      setDraftFacilityScale(null);
      await queryClient.invalidateQueries({ queryKey: ["facility-setting"] });
    },
    onError: (error) => {
      toast.error(formatApiError(error, "事業所設定の更新に失敗しました"));
    },
  });

  if (!canManageTenant) {
    return (
      <Card className="rounded-2xl border-border/70 shadow-sm">
        <CardContent className="p-10 text-center">
          <p className="font-medium">権限がありません</p>
          <p className="mt-1 text-sm text-muted-foreground">
            tenants:manage 権限を持つ管理者ユーザーでログインしてください。
          </p>
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-4">
      <Card className="rounded-2xl border-border/70 shadow-sm">
        <CardHeader>
          <CardTitle className="text-base">事業所設定</CardTitle>
          <CardDescription>
            所在地と事業所規模を設定します。請求計算の地域区分・基本単位数の解決に利用されます。
          </CardDescription>
        </CardHeader>

        <CardContent className="space-y-6">
          {facilitySettingQuery.isPending && (
            <div className="space-y-4">
              <Skeleton className="h-10 w-full rounded-xl" />
              <Skeleton className="h-10 w-full rounded-xl" />
            </div>
          )}

          {!facilitySettingQuery.isPending && facilitySettingQuery.isError && (
            <div className="rounded-xl border border-destructive/40 p-4">
              <p className="font-medium">事業所設定の取得に失敗しました</p>
              <p className="mt-1 text-sm text-muted-foreground">時間をおいて再試行してください。</p>
              <Button
                variant="outline"
                className="mt-3 rounded-xl"
                onClick={() => facilitySettingQuery.refetch()}
              >
                再読み込み
              </Button>
            </div>
          )}

          {!facilitySettingQuery.isPending && !facilitySettingQuery.isError && facilitySettingQuery.data && (
            <>
              <div className="space-y-2">
                <label htmlFor="city-name" className="flex items-center gap-2 text-sm font-medium">
                  <MapPin className="size-4" />
                  所在地（市区町村）
                </label>
                <Select value={cityName} onValueChange={setDraftCityName}>
                  <SelectTrigger id="city-name" className="rounded-xl">
                    <SelectValue placeholder="市区町村を選択" />
                  </SelectTrigger>
                  <SelectContent>
                    {facilitySettingQuery.data.city_options.map((city) => (
                      <SelectItem key={city} value={city}>
                        {city}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <label htmlFor="facility-scale" className="flex items-center gap-2 text-sm font-medium">
                  <Building2 className="size-4" />
                  事業所規模
                </label>
                <Select
                  value={facilityScale}
                  onValueChange={(value) => setDraftFacilityScale(value as FacilityScale)}
                >
                  <SelectTrigger id="facility-scale" className="rounded-xl">
                    <SelectValue placeholder="事業所規模を選択" />
                  </SelectTrigger>
                  <SelectContent>
                    {facilitySettingQuery.data.facility_scale_options.map((option) => (
                      <SelectItem key={option.value} value={option.value}>
                        {option.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div className="flex justify-end">
                <Button
                  className="rounded-xl"
                  onClick={() => saveMutation.mutate()}
                  disabled={!cityName || !facilityScale || saveMutation.isPending}
                >
                  {saveMutation.isPending ? "保存中..." : "設定を保存"}
                </Button>
              </div>
            </>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
