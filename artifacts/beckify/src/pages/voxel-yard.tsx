import { Layout } from "@/components/Layout";
import { VoxelYard } from "@/components/games/VoxelYard";
import { SchemaHead } from "@/components/seo/SchemaHead";

export default function VoxelYardPage() {
  return <Layout showAds={false}><SchemaHead title="Voxel Yard | Beckify Games" description="Play Voxel Yard, a first-person WebGL voxel sandbox: walk a seeded continent, mine and place blocks, fly, and keep your world in this browser." path="/games/voxel-yard" /><VoxelYard /></Layout>;
}
