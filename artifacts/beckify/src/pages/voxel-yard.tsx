import { Layout } from "@/components/Layout";
import { VoxelYard } from "@/components/games/VoxelYard";
import { SchemaHead } from "@/components/seo/SchemaHead";

export default function VoxelYardPage() {
  return <Layout showAds={false}><SchemaHead title="Voxel Yard | Beckify Games" description="Play Voxel Yard, a touch-friendly isometric voxel-building sandbox: mine, place, and reshape a procedurally generated island, playable on iPad." path="/games/voxel-yard" /><VoxelYard /></Layout>;
}
